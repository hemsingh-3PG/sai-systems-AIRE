---
copyright: "Copyright © 2026 3Pillar Global, Inc."
license: "Proprietary - 3Pillar Background IP"
date: "2026-04-24"
component: "3Pillar AIRE SDLC Agentic Framework"
legal_notice: |
  PROPERTY OF 3PILLAR GLOBAL, INC. - CONFIDENTIAL & PROPRIETARY

  Component: 3Pillar AIRE SDLC Agentic Framework
  Copyright © 2026 3Pillar Global, Inc. All Rights Reserved.

  This file contains 3Pillar Pre-Existing Materials. When used in client deliveries, this component is licensed pursuant to the Master Services Agreement between 3Pillar Global and the client.

  USE RESTRICTIONS:
  Unauthorized use, reproduction, or distribution is strictly prohibited.
---

# Clean Architecture Guidelines

## The Dependency Rule

**Dependencies point INWARD only.** Inner layers cannot know about outer layers.

```
┌───────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                       │
│     (Frameworks, Drivers, UI, DB, External APIs)              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  APPLICATION LAYER                       │  │
│  │          (Use Cases, Application Services)               │  │
│  │  ┌─────────────────────────────────────────────────────┐│  │
│  │  │                  DOMAIN LAYER                        ││  │
│  │  │       (Entities, Business Rules, Interfaces)        ││  │
│  │  └─────────────────────────────────────────────────────┘│  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
                            ↑
            Dependencies point INWARD only
```

---

## Layer Responsibilities

### Domain Layer (Innermost)
**Pure business logic. NO external dependencies.**

| Contains | Does NOT Contain |
|----------|------------------|
| Entities (User, Order, Product) | Database queries |
| Value Objects (Email, Money) | HTTP requests |
| Domain Services | Framework code |
| Repository Interfaces | UI components |
| Business Rules | External API calls |

```javascript
// ✅ GOOD: Pure domain entity
class Order {
  constructor(id, items, customer) {
    this.id = id;
    this.items = items;
    this.customer = customer;
    this.status = 'pending';
  }
  
  calculateTotal() {
    return this.items.reduce((sum, item) => sum + item.price, 0);
  }
  
  canBeCancelled() {
    return this.status === 'pending';
  }
}

// ✅ GOOD: Repository interface (not implementation)
class OrderRepository {
  async findById(id) { throw new Error('Must implement'); }
  async save(order) { throw new Error('Must implement'); }
}
```

---

### Application Layer
**Orchestrates use cases. Calls domain logic.**

| Contains | Does NOT Contain |
|----------|------------------|
| Use Cases | Business rules (those go in Domain) |
| Application Services | Database code |
| DTOs (Data Transfer Objects) | HTTP/UI code |
| Command/Query handlers | External API implementations |

```javascript
// ✅ GOOD: Use case orchestrating domain
class CreateOrderUseCase {
  constructor(orderRepository, inventoryService, eventBus) {
    this.orderRepository = orderRepository;
    this.inventoryService = inventoryService;
    this.eventBus = eventBus;
  }
  
  async execute(orderData) {
    // 1. Create domain entity
    const order = new Order(generateId(), orderData.items, orderData.customer);
    
    // 2. Apply business rules
    if (order.calculateTotal() > 10000) {
      throw new OrderLimitExceededError();
    }
    
    // 3. Persist via repository
    await this.orderRepository.save(order);
    
    // 4. Emit domain event
    this.eventBus.emit('order.created', order);
    
    return order;
  }
}
```

---

### Infrastructure Layer (Outermost)
**Implements interfaces. Connects to external world.**

| Contains | Does NOT Contain |
|----------|------------------|
| Database implementations | Business logic |
| API clients | Domain rules |
| Framework configuration | Use case orchestration |
| Controllers/UI | Entity definitions |
| Repository implementations | |

```javascript
// ✅ GOOD: Infrastructure implements domain interface
class PostgresOrderRepository extends OrderRepository {
  constructor(db) {
    super();
    this.db = db;
  }
  
  async findById(id) {
    const row = await this.db.query('SELECT * FROM orders WHERE id = ?', [id]);
    return this.mapToEntity(row);
  }
  
  async save(order) {
    await this.db.query(
      'INSERT INTO orders (id, customer_id, status) VALUES (?, ?, ?)',
      [order.id, order.customer.id, order.status]
    );
  }
}
```

---

## Directory Structure

```
src/
├── domain/                    # INNERMOST - pure business logic
│   ├── entities/
│   │   ├── Order.js
│   │   └── User.js
│   ├── valueObjects/
│   │   └── Money.js
│   ├── repositories/          # Interfaces only!
│   │   └── OrderRepository.js
│   └── services/
│       └── PricingService.js
│
├── application/               # Use cases, orchestration
│   ├── useCases/
│   │   ├── CreateOrderUseCase.js
│   │   └── CancelOrderUseCase.js
│   └── dto/
│       └── OrderDTO.js
│
└── infrastructure/            # OUTERMOST - external world
    ├── persistence/
    │   └── PostgresOrderRepository.js
    ├── api/
    │   └── StripePaymentGateway.js
    └── web/
        └── OrderController.js
```

---

## Validation Checklist

| Rule | Check |
|------|-------|
| ✅ Domain has no imports from infrastructure | `grep -r "import.*infrastructure" src/domain/` returns nothing |
| ✅ Domain has no framework dependencies | No express, react, prisma in domain/ |
| ✅ Application only imports domain | No infrastructure imports in application/ |
| ✅ Infrastructure implements domain interfaces | Repository classes extend domain interfaces |
| ✅ Dependencies are injected | No `new DatabaseClient()` in use cases |

---

## Common Violations

| Violation | Why It's Bad | Fix |
|-----------|--------------|-----|
| Entity calls database | Domain depends on infrastructure | Use repository interface |
| Use case knows about HTTP | Application coupled to web | Use DTOs |
| Business rules in controller | Logic in wrong layer | Move to domain |
| Hardcoded external services | Untestable | Inject via interface |

---

## Testing Benefits

With clean architecture, each layer is testable in isolation:

```javascript
// Domain testing - no mocks needed
test('Order.calculateTotal sums item prices', () => {
  const order = new Order('1', [{ price: 100 }, { price: 50 }], customer);
  expect(order.calculateTotal()).toBe(150);
});

// Application testing - mock repositories
test('CreateOrderUseCase saves and emits event', async () => {
  const mockRepo = { save: jest.fn() };
  const mockEventBus = { emit: jest.fn() };
  const useCase = new CreateOrderUseCase(mockRepo, mockEventBus);
  
  await useCase.execute(orderData);
  
  expect(mockRepo.save).toHaveBeenCalled();
  expect(mockEventBus.emit).toHaveBeenCalledWith('order.created', expect.any(Order));
});
```
