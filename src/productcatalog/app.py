#!/usr/bin/env python3

import os
import json
import logging
from flask import Flask, jsonify, request
from flask_cors import CORS
import time
import random

# OpenTelemetry imports
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configure OpenTelemetry
def configure_opentelemetry():
    # Create resource with service information
    resource = Resource.create({
        "service.name": "productcatalog",
        "service.version": "1.0.0",
        "service.instance.id": os.environ.get("HOSTNAME", "unknown"),
    })
    
    # Configure tracing
    trace_provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(trace_provider)
    
    # Configure OTLP exporter for traces
    otlp_exporter = OTLPSpanExporter(
        endpoint=os.environ.get("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "http://otel-collector:4317"),
        insecure=True
    )
    
    span_processor = BatchSpanProcessor(otlp_exporter)
    trace_provider.add_span_processor(span_processor)
    
    # Configure metrics
    metric_reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(
            endpoint=os.environ.get("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "http://otel-collector:4317"),
            insecure=True
        ),
        export_interval_millis=5000,
    )
    
    metrics_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    metrics.set_meter_provider(metrics_provider)
    
    return trace.get_tracer(__name__), metrics.get_meter(__name__)

# Initialize OpenTelemetry
tracer, meter = configure_opentelemetry()

# Create Flask app
app = Flask(__name__)
CORS(app)

# Auto-instrument Flask and requests
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

# Create custom metrics
request_counter = meter.create_counter(
    name="product_requests_total",
    description="Total number of product requests",
    unit="1"
)

request_duration = meter.create_histogram(
    name="product_request_duration_seconds",
    description="Duration of product requests",
    unit="s"
)

# Sample product data
PRODUCTS = [
    {
        "id": "OLJCESPC7Z",
        "name": "Vintage Typewriter",
        "description": "This typewriter looks good in your living room.",
        "picture": "/static/img/products/typewriter.jpg",
        "price_usd": {"currency_code": "USD", "units": 67, "nanos": 990000000},
        "categories": ["vintage"]
    },
    {
        "id": "66VCHSJNUP",
        "name": "Vintage Camera Lens",
        "description": "You won't have a camera to use it and it probably doesn't work anyway.",
        "picture": "/static/img/products/camera-lens.jpg",
        "price_usd": {"currency_code": "USD", "units": 12, "nanos": 490000000},
        "categories": ["photography", "vintage"]
    },
    {
        "id": "1YMWWN1N4O",
        "name": "Home Barista Kit",
        "description": "Always wanted to brew coffee with Chemex and Aeropress at home?",
        "picture": "/static/img/products/barista-kit.jpg",
        "price_usd": {"currency_code": "USD", "units": 124, "nanos": 0},
        "categories": ["kitchen"]
    },
    {
        "id": "L9ECAV7KIM",
        "name": "Terrarium",
        "description": "This terrarium will looks great in your white painted living room.",
        "picture": "/static/img/products/terrarium.jpg",
        "price_usd": {"currency_code": "USD", "units": 36, "nanos": 450000000},
        "categories": ["gardening"]
    },
    {
        "id": "2ZYFJ3GM2N",
        "name": "Film Camera",
        "description": "This camera looks like it's a film camera, but it's actually digital.",
        "picture": "/static/img/products/film-camera.jpg",
        "price_usd": {"currency_code": "USD", "units": 2245, "nanos": 0},
        "categories": ["photography", "vintage"]
    }
]

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "productcatalog"})

@app.route('/products')
def list_products():
    """List all products"""
    start_time = time.time()
    
    with tracer.start_as_current_span("list_products") as span:
        span.set_attribute("product.count", len(PRODUCTS))
        
        # Simulate some processing time
        time.sleep(random.uniform(0.01, 0.05))
        
        # Add custom attributes
        span.set_attribute("http.method", request.method)
        span.set_attribute("http.url", request.url)
        
        # Record metrics
        request_counter.add(1, {"endpoint": "/products", "method": "GET"})
        
        duration = time.time() - start_time
        request_duration.record(duration, {"endpoint": "/products", "method": "GET"})
        
        logger.info(f"Listed {len(PRODUCTS)} products")
        
        return jsonify({"products": PRODUCTS})

@app.route('/products/<product_id>')
def get_product(product_id):
    """Get a specific product by ID"""
    start_time = time.time()
    
    with tracer.start_as_current_span("get_product") as span:
        span.set_attribute("product.id", product_id)
        span.set_attribute("http.method", request.method)
        span.set_attribute("http.url", request.url)
        
        # Simulate database lookup time
        time.sleep(random.uniform(0.005, 0.02))
        
        # Find product
        product = next((p for p in PRODUCTS if p["id"] == product_id), None)
        
        if product:
            span.set_attribute("product.found", True)
            span.set_attribute("product.name", product["name"])
            
            # Record metrics
            request_counter.add(1, {"endpoint": "/products/{id}", "method": "GET", "status": "found"})
            
            duration = time.time() - start_time
            request_duration.record(duration, {"endpoint": "/products/{id}", "method": "GET", "status": "found"})
            
            logger.info(f"Found product: {product['name']}")
            return jsonify(product)
        else:
            span.set_attribute("product.found", False)
            span.set_attribute("error", True)
            
            # Record metrics
            request_counter.add(1, {"endpoint": "/products/{id}", "method": "GET", "status": "not_found"})
            
            duration = time.time() - start_time
            request_duration.record(duration, {"endpoint": "/products/{id}", "method": "GET", "status": "not_found"})
            
            logger.warning(f"Product not found: {product_id}")
            return jsonify({"error": "Product not found"}), 404

@app.route('/products/search')
def search_products():
    """Search products by query"""
    start_time = time.time()
    query = request.args.get('q', '').lower()
    
    with tracer.start_as_current_span("search_products") as span:
        span.set_attribute("search.query", query)
        span.set_attribute("http.method", request.method)
        span.set_attribute("http.url", request.url)
        
        # Simulate search processing time
        time.sleep(random.uniform(0.02, 0.08))
        
        # Filter products based on query
        if query:
            filtered_products = [
                p for p in PRODUCTS 
                if query in p["name"].lower() or 
                   query in p["description"].lower() or
                   any(query in cat.lower() for cat in p["categories"])
            ]
        else:
            filtered_products = PRODUCTS
        
        span.set_attribute("search.results_count", len(filtered_products))
        
        # Record metrics
        request_counter.add(1, {"endpoint": "/products/search", "method": "GET"})
        
        duration = time.time() - start_time
        request_duration.record(duration, {"endpoint": "/products/search", "method": "GET"})
        
        logger.info(f"Search for '{query}' returned {len(filtered_products)} results")
        
        return jsonify({
            "query": query,
            "products": filtered_products,
            "total": len(filtered_products)
        })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 7000))
    logger.info(f"Starting Product Catalog Service on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)

