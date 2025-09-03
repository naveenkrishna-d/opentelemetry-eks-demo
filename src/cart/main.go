package main

import (
    "context"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "sync"
    "time"

    "github.com/gin-contrib/cors"
    "github.com/gin-gonic/gin"
    "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/metric"
    "go.opentelemetry.io/otel/propagation"
    sdkmetric "go.opentelemetry.io/otel/sdk/metric"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
    "go.opentelemetry.io/otel/trace"
)

var (
    tracer trace.Tracer
    meter  metric.Meter
    
    // Metrics
    requestCounter metric.Int64Counter
    requestDuration metric.Float64Histogram
    cartItemsGauge metric.Int64UpDownCounter
)

// Cart represents a shopping cart
type Cart struct {
    UserID string     `json:"user_id"`
    Items  []CartItem `json:"items"`
    mutex  sync.RWMutex
}

// CartItem represents an item in the cart
type CartItem struct {
    ProductID string `json:"product_id"`
    Quantity  int    `json:"quantity"`
}

// Product represents a product from the catalog service
type Product struct {
    ID          string `json:"id"`
    Name        string `json:"name"`
    Description string `json:"description"`
    Picture     string `json:"picture"`
    PriceUSD    struct {
        CurrencyCode string `json:"currency_code"`
        Units        int64  `json:"units"`
        Nanos        int32  `json:"nanos"`
    } `json:"price_usd"`
    Categories []string `json:"categories"`
}

// In-memory cart storage (in production, this would be a database)
var carts = make(map[string]*Cart)
var cartsMutex sync.RWMutex

func initOpenTelemetry() func() {
    ctx := context.Background()

    // Create resource
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName("cart"),
            semconv.ServiceVersion("1.0.0"),
            semconv.ServiceInstanceID(getEnv("HOSTNAME", "unknown")),
        ),
    )
    if err != nil {
        log.Fatalf("failed to create resource: %v", err)
    }

    // Set up trace provider
    traceExporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint(getEnv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://otel-collector:4317")),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        log.Fatalf("failed to create trace exporter: %v", err)
    }

    traceProvider := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(traceExporter),
        sdktrace.WithResource(res),
    )
    otel.SetTracerProvider(traceProvider)

    // Set up metric provider
    metricExporter, err := otlpmetricgrpc.New(ctx,
        otlpmetricgrpc.WithEndpoint(getEnv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "http://otel-collector:4317")),
        otlpmetricgrpc.WithInsecure(),
    )
    if err != nil {
        log.Fatalf("failed to create metric exporter: %v", err)
    }

    metricProvider := sdkmetric.NewMeterProvider(
        sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter, sdkmetric.WithInterval(5*time.Second))),
        sdkmetric.WithResource(res),
    )
    otel.SetMeterProvider(metricProvider)

    // Set up propagator
    otel.SetTextMapPropagator(propagation.TraceContext{})

    // Initialize tracer and meter
    tracer = otel.Tracer("cart", trace.WithInstrumentationVersion("1.0.0"))
    meter = otel.Meter("cart", metric.WithInstrumentationVersion("1.0.0"))

    // Create metrics
    var err2 error
    requestCounter, err2 = meter.Int64Counter(
        "cart_requests_total",
        metric.WithDescription("Total number of cart requests"),
        metric.WithUnit("1"),
    )
    if err2 != nil {
        log.Printf("failed to create request counter: %v", err2)
    }

    requestDuration, err2 = meter.Float64Histogram(
        "cart_request_duration_seconds",
        metric.WithDescription("Duration of cart requests"),
        metric.WithUnit("s"),
    )
    if err2 != nil {
        log.Printf("failed to create request duration histogram: %v", err2)
    }

    cartItemsGauge, err2 = meter.Int64UpDownCounter(
        "cart_items_total",
        metric.WithDescription("Total number of items in all carts"),
        metric.WithUnit("1"),
    )
    if err2 != nil {
        log.Printf("failed to create cart items gauge: %v", err2)
    }

    return func() {
        if err := traceProvider.Shutdown(ctx); err != nil {
            log.Printf("failed to shutdown trace provider: %v", err)
        }
        if err := metricProvider.Shutdown(ctx); err != nil {
            log.Printf("failed to shutdown metric provider: %v", err)
        }
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getProductFromCatalog(ctx context.Context, productID string) (*Product, error) {
    ctx, span := tracer.Start(ctx, "get_product_from_catalog")
    defer span.End()

    span.SetAttributes(attribute.String("product.id", productID))

    catalogURL := getEnv("PRODUCT_CATALOG_SERVICE_ADDR", "http://productcatalog:7000")
    url := fmt.Sprintf("%s/products/%s", catalogURL, productID)

    client := &http.Client{
        Transport: otelhttp.NewTransport(http.DefaultTransport),
        Timeout:   10 * time.Second,
    }

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        span.RecordError(err)
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    resp, err := client.Do(req)
    if err != nil {
        span.RecordError(err)
        return nil, fmt.Errorf("failed to get product: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        span.SetAttributes(attribute.Int("http.status_code", resp.StatusCode))
        return nil, fmt.Errorf("product not found: %s", productID)
    }

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        span.RecordError(err)
        return nil, fmt.Errorf("failed to read response: %w", err)
    }

    var product Product
    if err := json.Unmarshal(body, &product); err != nil {
        span.RecordError(err)
        return nil, fmt.Errorf("failed to unmarshal product: %w", err)
    }

    span.SetAttributes(attribute.String("product.name", product.Name))
    return &product, nil
}

func healthCheck(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{
        "status":  "healthy",
        "service": "cart",
    })
}

func addToCart(c *gin.Context) {
    start := time.Now()
    ctx := c.Request.Context()
    ctx, span := tracer.Start(ctx, "add_to_cart")
    defer span.End()

    userID := c.Param("user_id")
    span.SetAttributes(attribute.String("user.id", userID))

    var item CartItem
    if err := c.ShouldBindJSON(&item); err != nil {
        span.RecordError(err)
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
        return
    }

    span.SetAttributes(
        attribute.String("product.id", item.ProductID),
        attribute.Int("item.quantity", item.Quantity),
    )

    // Validate product exists
    _, err := getProductFromCatalog(ctx, item.ProductID)
    if err != nil {
        span.RecordError(err)
        c.JSON(http.StatusBadRequest, gin.H{"error": "Product not found"})
        return
    }

    // Add to cart
    cartsMutex.Lock()
    cart, exists := carts[userID]
    if !exists {
        cart = &Cart{
            UserID: userID,
            Items:  []CartItem{},
        }
        carts[userID] = cart
    }
    cartsMutex.Unlock()

    cart.mutex.Lock()
    // Check if item already exists in cart
    found := false
    for i, existingItem := range cart.Items {
        if existingItem.ProductID == item.ProductID {
            cart.Items[i].Quantity += item.Quantity
            found = true
            break
        }
    }
    if !found {
        cart.Items = append(cart.Items, item)
    }
    cart.mutex.Unlock()

    // Record metrics
    requestCounter.Add(ctx, 1, metric.WithAttributes(
        attribute.String("endpoint", "/cart/{user_id}/items"),
        attribute.String("method", "POST"),
    ))

    duration := time.Since(start).Seconds()
    requestDuration.Record(ctx, duration, metric.WithAttributes(
        attribute.String("endpoint", "/cart/{user_id}/items"),
        attribute.String("method", "POST"),
    ))

    cartItemsGauge.Add(ctx, int64(item.Quantity))

    log.Printf("Added %d of product %s to cart for user %s", item.Quantity, item.ProductID, userID)

    c.JSON(http.StatusOK, gin.H{"message": "Item added to cart"})
}

func getCart(c *gin.Context) {
    start := time.Now()
    ctx := c.Request.Context()
    ctx, span := tracer.Start(ctx, "get_cart")
    defer span.End()

    userID := c.Param("user_id")
    span.SetAttributes(attribute.String("user.id", userID))

    cartsMutex.RLock()
    cart, exists := carts[userID]
    cartsMutex.RUnlock()

    if !exists {
        cart = &Cart{
            UserID: userID,
            Items:  []CartItem{},
        }
    }

    cart.mutex.RLock()
    itemCount := len(cart.Items)
    cartData := *cart
    cart.mutex.RUnlock()

    span.SetAttributes(attribute.Int("cart.item_count", itemCount))

    // Record metrics
    requestCounter.Add(ctx, 1, metric.WithAttributes(
        attribute.String("endpoint", "/cart/{user_id}"),
        attribute.String("method", "GET"),
    ))

    duration := time.Since(start).Seconds()
    requestDuration.Record(ctx, duration, metric.WithAttributes(
        attribute.String("endpoint", "/cart/{user_id}"),
        attribute.String("method", "GET"),
    ))

    log.Printf("Retrieved cart for user %s with %d items", userID, itemCount)

    c.JSON(http.StatusOK, cartData)
}

func emptyCart(c *gin.Context) {
    start := time.Now()
    ctx := c.Request.Context()
    ctx, span := tracer.Start(ctx, "empty_cart")
    defer span.End()

    userID := c.Param("user_id")
    span.SetAttributes(attribute.String("user.id", userID))

    cartsMutex.RLock()
    cart, exists := carts[userID]
    cartsMutex.RUnlock()

    if exists {
        cart.mutex.Lock()
        itemCount := 0
        for _, item := range cart.Items {
            itemCount += item.Quantity
        }
        cart.Items = []CartItem{}
        cart.mutex.Unlock()

        cartItemsGauge.Add(ctx, -int64(itemCount))
        span.SetAttributes(attribute.Int("cart.items_removed", itemCount))
    }

    // Record metrics
    requestCounter.Add(ctx, 1, metric.WithAttributes(
        attribute.String("endpoint", "/cart/{user_id}"),
        attribute.String("method", "DELETE"),
    ))

    duration := time.Since(start).Seconds()
    requestDuration.Record(ctx, duration, metric.WithAttributes(
        attribute.String("endpoint", "/cart/{user_id}"),
        attribute.String("method", "DELETE"),
    ))

    log.Printf("Emptied cart for user %s", userID)

    c.JSON(http.StatusOK, gin.H{"message": "Cart emptied"})
}

func main() {
    // Initialize OpenTelemetry
    shutdown := initOpenTelemetry()
    defer shutdown()

    // Create Gin router
    r := gin.Default()

    // Add CORS middleware
    r.Use(cors.New(cors.Config{
        AllowOrigins:     []string{"*"},
        AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
        AllowHeaders:     []string{"*"},
        ExposeHeaders:    []string{"*"},
        AllowCredentials: true,
    }))

    // Add OpenTelemetry middleware
    r.Use(otelgin.Middleware("cart"))

    // Routes
    r.GET("/health", healthCheck)
    r.POST("/cart/:user_id/items", addToCart)
    r.GET("/cart/:user_id", getCart)
    r.DELETE("/cart/:user_id", emptyCart)

    // Start server
    port := getEnv("PORT", "7001")
    log.Printf("Starting Cart Service on port %s", port)
    log.Fatal(r.Run(":" + port))
}

