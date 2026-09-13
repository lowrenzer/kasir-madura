# Madura Cashier System - Backend

## Setup & Run

1. Install Go 1.21+
2. Install dependencies: `go mod tidy`
3. Configure `.env` file:
   - DB_HOST=localhost
   - DB_PORT=3306
   - DB_USER=root
   - DB_PASSWORD=your_password
   - DB_NAME=tokomadura
4. Run: `go run main.go`
5. API available at http://localhost:8080

## Database Setup

MySQL database needed. Tables created automatically on first run.

## API Endpoints

- POST /api/login - Login user
- GET /api/stock - Get all stock
- POST /api/stock - Add stock
- PUT /api/stock/:id - Update stock
- DELETE /api/stock/:id - Delete stock
- POST /api/orders - Create order
- GET /api/orders - Get all orders
- GET /api/orders/:id - Get single order
- PUT /api/orders/:id/status - Update order status
