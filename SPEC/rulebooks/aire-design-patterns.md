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

# Design Patterns Quick Reference



---

## When to Use Which Pattern

| Pattern | Use When | Avoid When |
|---------|----------|------------|
| **Factory** | Complex object creation, hiding implementation | Simple constructors work |
| **Strategy** | Multiple algorithms, runtime switching | Single fixed algorithm |
| **Observer** | Event-driven, decoupled notifications | Tight coupling required |
| **Repository** | Data access abstraction needed | Simple direct queries |
| **Adapter** | Integrating third-party APIs | Internal code only |
| **Decorator** | Adding behavior without inheritance | Simple extension works |
| **Singleton** | True single instance needed | Almost never - avoid |

---

## Pattern Examples

### Factory Pattern
**Use for**: Creating objects with complex setup or multiple variants.

```javascript
// ❌ BAD: Creating directly with conditionals
function createPayment(type, amount) {
  if (type === 'credit') return new CreditPayment(amount);
  if (type === 'debit') return new DebitPayment(amount);
  // Adding new types requires modifying this function
}

// ✅ GOOD: Factory with registration
class PaymentFactory {
  constructor() {
    this.creators = {};
  }
  
  register(type, creator) {
    this.creators[type] = creator;
  }
  
  create(type, amount) {
    const creator = this.creators[type];
    if (!creator) throw new Error(`Unknown payment type: ${type}`);
    return creator(amount);
  }
}

// Usage - extend without modifying
factory.register('credit', (amt) => new CreditPayment(amt));
factory.register('crypto', (amt) => new CryptoPayment(amt));
```

---

### Strategy Pattern
**Use for**: Algorithms that can be swapped at runtime.

```javascript
// ❌ BAD: Conditional logic in main class
class Sorter {
  sort(data, algorithm) {
    if (algorithm === 'quick') return this.quickSort(data);
    if (algorithm === 'merge') return this.mergeSort(data);
    if (algorithm === 'bubble') return this.bubbleSort(data);
  }
}

// ✅ GOOD: Strategy injection
class Sorter {
  constructor(strategy) {
    this.strategy = strategy;
  }
  
  sort(data) {
    return this.strategy.execute(data);
  }
}

// Strategies are separate classes
class QuickSortStrategy {
  execute(data) { /* quick sort logic */ }
}

class MergeSortStrategy {
  execute(data) { /* merge sort logic */ }
}

// Usage - swap at runtime
const sorter = new Sorter(new QuickSortStrategy());
sorter.sort(data);
```

---

### Repository Pattern
**Use for**: Abstracting data access from business logic.

```javascript
// ❌ BAD: Direct database access in service
class UserService {
  async getUser(id) {
    const result = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    return result.rows[0];
  }
}

// ✅ GOOD: Repository abstraction
class UserRepository {
  async findById(id) {
    const result = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    return this.mapToEntity(result.rows[0]);
  }
  
  mapToEntity(row) {
    return new User(row.id, row.email, row.name);
  }
}

class UserService {
  constructor(userRepository) {
    this.userRepository = userRepository;
  }
  
  async getUser(id) {
    return this.userRepository.findById(id);
  }
}
```

---

### Observer Pattern
**Use for**: Decoupled event-driven communication.

```javascript
// ❌ BAD: Direct calls create tight coupling
class OrderService {
  async createOrder(order) {
    await this.orderRepo.save(order);
    await this.emailService.sendConfirmation(order);
    await this.inventoryService.reserve(order.items);
    await this.analyticsService.track('order_created', order);
  }
}

// ✅ GOOD: Event-based decoupling
class OrderService {
  constructor(orderRepo, eventBus) {
    this.orderRepo = orderRepo;
    this.eventBus = eventBus;
  }
  
  async createOrder(order) {
    await this.orderRepo.save(order);
    this.eventBus.emit('order.created', order);
  }
}

// Listeners handle side effects
eventBus.on('order.created', (order) => emailService.sendConfirmation(order));
eventBus.on('order.created', (order) => inventoryService.reserve(order.items));
```

---

### Adapter Pattern
**Use for**: Integrating external APIs with your interface.

```javascript
// External API has different interface
class StripeAPI {
  createCharge(cents, currency, token) { /* ... */ }
}

// Your interface
class PaymentGateway {
  charge(amount, paymentMethod) { /* ... */ }
}

// ✅ Adapter translates between them
class StripeAdapter extends PaymentGateway {
  constructor(stripeApi) {
    this.stripe = stripeApi;
  }
  
  charge(amount, paymentMethod) {
    const cents = amount * 100;
    return this.stripe.createCharge(cents, 'usd', paymentMethod.token);
  }
}
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| **God Object** | One class does everything | Split into focused classes |
| **Spaghetti Code** | No clear structure | Apply layered architecture |
| **Golden Hammer** | Using one pattern everywhere | Choose pattern by context |
| **Premature Optimization** | Complex patterns before needed | Start simple, refactor when needed |
| **Singleton Abuse** | Global state everywhere | Use dependency injection |
| **Copy-Paste Programming** | Duplicated code | Extract to shared functions/classes |

---

## Decision Checklist

Before adding a pattern, ask:

- [ ] Does this solve a real problem I have now?
- [ ] Is the simpler approach actually causing issues?
- [ ] Will my team understand this pattern?
- [ ] Does it make the code more testable?
- [ ] Am I adding flexibility I'll actually use?

**Remember**: Patterns add complexity. Only use when benefit > cost.