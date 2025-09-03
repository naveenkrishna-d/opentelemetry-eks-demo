// Initialize OpenTelemetry before importing other modules
require('./tracing');

const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { trace, metrics } = require('@opentelemetry/api');
const path = require('path');

const app = express();
const port = process.env.PORT || 8080;

// Get tracer and meter
const tracer = trace.getTracer('frontend', '1.0.0');
const meter = metrics.getMeter('frontend', '1.0.0');

// Create custom metrics
const requestCounter = meter.createCounter('frontend_requests_total', {
  description: 'Total number of frontend requests',
  unit: '1'
});

const requestDuration = meter.createHistogram('frontend_request_duration_seconds', {
  description: 'Duration of frontend requests',
  unit: 's'
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Service URLs
const PRODUCT_CATALOG_URL = process.env.PRODUCT_CATALOG_SERVICE_ADDR || 'http://productcatalog:7000';
const CART_SERVICE_URL = process.env.CART_SERVICE_ADDR || 'http://cart:7001';

// Helper function to make HTTP requests with tracing
async function makeRequest(url, options = {}) {
  const span = trace.getActiveSpan();
  if (span) {
    span.setAttributes({
      'http.url': url,
      'http.method': options.method || 'GET'
    });
  }

  try {
    const response = await axios({
      url,
      timeout: 10000,
      ...options
    });
    
    if (span) {
      span.setAttributes({
        'http.status_code': response.status,
        'http.response.size': JSON.stringify(response.data).length
      });
    }
    
    return response;
  } catch (error) {
    if (span) {
      span.recordException(error);
      span.setStatus({ code: 2, message: error.message });
    }
    throw error;
  }
}

// Routes
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'frontend' });
});

app.get('/', (req, res) => {
  const startTime = Date.now();
  
  const span = tracer.startSpan('serve_homepage');
  span.setAttributes({
    'http.method': req.method,
    'http.url': req.url,
    'user.agent': req.get('User-Agent') || 'unknown'
  });

  // Record metrics
  requestCounter.add(1, { endpoint: '/', method: 'GET' });

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>OpenTelemetry Demo Shop</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 800px; margin: 0 auto; }
            .product { border: 1px solid #ddd; padding: 20px; margin: 10px 0; border-radius: 5px; }
            .cart { background: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 5px; }
            button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 3px; cursor: pointer; }
            button:hover { background: #0056b3; }
            .user-id { margin: 20px 0; }
            input { padding: 8px; margin: 5px; border: 1px solid #ddd; border-radius: 3px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>OpenTelemetry Demo Shop</h1>
            <p>This is a demonstration of OpenTelemetry distributed tracing across microservices.</p>
            
            <div class="user-id">
                <label>User ID: </label>
                <input type="text" id="userId" value="user123" placeholder="Enter user ID">
            </div>
            
            <h2>Products</h2>
            <div id="products">Loading products...</div>
            
            <h2>Shopping Cart</h2>
            <div id="cart" class="cart">Loading cart...</div>
            
            <script>
                const userId = document.getElementById('userId');
                let currentUserId = 'user123';
                
                userId.addEventListener('change', (e) => {
                    currentUserId = e.target.value || 'user123';
                    loadCart();
                });
                
                async function loadProducts() {
                    try {
                        const response = await fetch('/api/products');
                        const data = await response.json();
                        const productsDiv = document.getElementById('products');
                        
                        productsDiv.innerHTML = data.products.map(product => \`
                            <div class="product">
                                <h3>\${product.name}</h3>
                                <p>\${product.description}</p>
                                <p><strong>Price: $\${product.price_usd.units}.\${String(product.price_usd.nanos).padStart(9, '0').slice(0, 2)}</strong></p>
                                <button onclick="addToCart('\${product.id}')">Add to Cart</button>
                            </div>
                        \`).join('');
                    } catch (error) {
                        document.getElementById('products').innerHTML = '<p>Error loading products</p>';
                        console.error('Error loading products:', error);
                    }
                }
                
                async function addToCart(productId) {
                    try {
                        const response = await fetch(\`/api/cart/\${currentUserId}/items\`, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ product_id: productId, quantity: 1 })
                        });
                        
                        if (response.ok) {
                            loadCart();
                            alert('Item added to cart!');
                        } else {
                            alert('Error adding item to cart');
                        }
                    } catch (error) {
                        alert('Error adding item to cart');
                        console.error('Error adding to cart:', error);
                    }
                }
                
                async function loadCart() {
                    try {
                        const response = await fetch(\`/api/cart/\${currentUserId}\`);
                        const cart = await response.json();
                        const cartDiv = document.getElementById('cart');
                        
                        if (cart.items && cart.items.length > 0) {
                            cartDiv.innerHTML = \`
                                <h3>Cart for \${cart.user_id}</h3>
                                <ul>
                                    \${cart.items.map(item => \`<li>Product: \${item.product_id}, Quantity: \${item.quantity}</li>\`).join('')}
                                </ul>
                                <button onclick="emptyCart()">Empty Cart</button>
                            \`;
                        } else {
                            cartDiv.innerHTML = \`<p>Cart is empty for user: \${currentUserId}</p>\`;
                        }
                    } catch (error) {
                        document.getElementById('cart').innerHTML = '<p>Error loading cart</p>';
                        console.error('Error loading cart:', error);
                    }
                }
                
                async function emptyCart() {
                    try {
                        const response = await fetch(\`/api/cart/\${currentUserId}\`, {
                            method: 'DELETE'
                        });
                        
                        if (response.ok) {
                            loadCart();
                            alert('Cart emptied!');
                        } else {
                            alert('Error emptying cart');
                        }
                    } catch (error) {
                        alert('Error emptying cart');
                        console.error('Error emptying cart:', error);
                    }
                }
                
                // Load initial data
                loadProducts();
                loadCart();
            </script>
        </div>
    </body>
    </html>
  `);

  const duration = (Date.now() - startTime) / 1000;
  requestDuration.record(duration, { endpoint: '/', method: 'GET' });
  
  span.end();
});

// API Routes
app.get('/api/products', async (req, res) => {
  const startTime = Date.now();
  
  const span = tracer.startSpan('get_products');
  span.setAttributes({
    'http.method': req.method,
    'http.url': req.url
  });

  try {
    const response = await makeRequest(`${PRODUCT_CATALOG_URL}/products`);
    
    span.setAttributes({
      'products.count': response.data.products ? response.data.products.length : 0
    });

    // Record metrics
    requestCounter.add(1, { endpoint: '/api/products', method: 'GET', status: 'success' });
    
    res.json(response.data);
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
    
    // Record metrics
    requestCounter.add(1, { endpoint: '/api/products', method: 'GET', status: 'error' });
    
    console.error('Error fetching products:', error.message);
    res.status(500).json({ error: 'Failed to fetch products' });
  } finally {
    const duration = (Date.now() - startTime) / 1000;
    requestDuration.record(duration, { endpoint: '/api/products', method: 'GET' });
    span.end();
  }
});

app.post('/api/cart/:userId/items', async (req, res) => {
  const startTime = Date.now();
  const { userId } = req.params;
  
  const span = tracer.startSpan('add_to_cart');
  span.setAttributes({
    'http.method': req.method,
    'http.url': req.url,
    'user.id': userId,
    'product.id': req.body.product_id,
    'item.quantity': req.body.quantity
  });

  try {
    const response = await makeRequest(`${CART_SERVICE_URL}/cart/${userId}/items`, {
      method: 'POST',
      data: req.body,
      headers: { 'Content-Type': 'application/json' }
    });

    // Record metrics
    requestCounter.add(1, { endpoint: '/api/cart/{userId}/items', method: 'POST', status: 'success' });
    
    res.json(response.data);
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
    
    // Record metrics
    requestCounter.add(1, { endpoint: '/api/cart/{userId}/items', method: 'POST', status: 'error' });
    
    console.error('Error adding to cart:', error.message);
    res.status(500).json({ error: 'Failed to add item to cart' });
  } finally {
    const duration = (Date.now() - startTime) / 1000;
    requestDuration.record(duration, { endpoint: '/api/cart/{userId}/items', method: 'POST' });
    span.end();
  }
});

app.get('/api/cart/:userId', async (req, res) => {
  const startTime = Date.now();
  const { userId } = req.params;
  
  const span = tracer.startSpan('get_cart');
  span.setAttributes({
    'http.method': req.method,
    'http.url': req.url,
    'user.id': userId
  });

  try {
    const response = await makeRequest(`${CART_SERVICE_URL}/cart/${userId}`);
    
    span.setAttributes({
      'cart.items_count': response.data.items ? response.data.items.length : 0
    });

    // Record metrics
    requestCounter.add(1, { endpoint: '/api/cart/{userId}', method: 'GET', status: 'success' });
    
    res.json(response.data);
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
    
    // Record metrics
    requestCounter.add(1, { endpoint: '/api/cart/{userId}', method: 'GET', status: 'error' });
    
    console.error('Error fetching cart:', error.message);
    res.status(500).json({ error: 'Failed to fetch cart' });
  } finally {
    const duration = (Date.now() - startTime) / 1000;
    requestDuration.record(duration, { endpoint: '/api/cart/{userId}', method: 'GET' });
    span.end();
  }
});

app.delete('/api/cart/:userId', async (req, res) => {
  const startTime = Date.now();
  const { userId } = req.params;
  
  const span = tracer.startSpan('empty_cart');
  span.setAttributes({
    'http.method': req.method,
    'http.url': req.url,
    'user.id': userId
  });

  try {
    const response = await makeRequest(`${CART_SERVICE_URL}/cart/${userId}`, {
      method: 'DELETE'
    });

    // Record metrics
    requestCounter.add(1, { endpoint: '/api/cart/{userId}', method: 'DELETE', status: 'success' });
    
    res.json(response.data);
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
    
    // Record metrics
    requestCounter.add(1, { endpoint: '/api/cart/{userId}', method: 'DELETE', status: 'error' });
    
    console.error('Error emptying cart:', error.message);
    res.status(500).json({ error: 'Failed to empty cart' });
  } finally {
    const duration = (Date.now() - startTime) / 1000;
    requestDuration.record(duration, { endpoint: '/api/cart/{userId}', method: 'DELETE' });
    span.end();
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Frontend service listening on port ${port}`);
});

