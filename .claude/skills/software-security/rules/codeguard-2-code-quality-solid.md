---
description: Code Quality, Dead Code Detection, Modularity, Readability, and SOLID Design Principles
globs: **/*
version: 1.0.1
alwaysApply: true
---

rule_id: codeguard-2-code-quality-solid

# Code Quality, Modularity & SOLID Principles

Ensure code is clean, maintainable, modular, and follows established design principles. Actively identify code smells, dead code, poor structure, and violations of SOLID principles. Provide actionable refactoring suggestions.

## 1. SOLID Principles - MANDATORY

### S - Single Responsibility Principle (SRP)

**Rule**: A class/module/function should have only ONE reason to change.

**Violations to Flag**:
- Classes with multiple unrelated responsibilities
- Functions doing more than one thing
- God classes/objects that handle everything
- Mixed concerns (e.g., business logic with UI code, data access with validation)

**Detection Patterns**:
```
# BAD - Multiple responsibilities
class UserManager:
    def authenticate_user(self, credentials): ...
    def send_email(self, user, message): ...
    def generate_report(self, user): ...
    def save_to_database(self, user): ...
    def format_user_data_for_ui(self, user): ...

# GOOD - Single responsibility
class UserAuthenticator:
    def authenticate(self, credentials): ...

class UserRepository:
    def save(self, user): ...
    def find_by_id(self, user_id): ...

class EmailService:
    def send(self, recipient, message): ...
```

**Indicators of SRP Violation**:
- Class/file has more than 200-300 lines of code
- Function has more than 20-30 lines of code
- Class name contains "And", "Or", "Manager", "Handler", "Processor", "Utils" doing unrelated things
- More than 5-7 public methods in a class
- Function name contains "And" (e.g., `validateAndSave`, `fetchAndProcess`)

### O - Open/Closed Principle (OCP)

**Rule**: Software entities should be open for extension but closed for modification.

**Violations to Flag**:
- Long if-else or switch statements for type checking
- Modifying existing code to add new functionality
- Type checking with instanceof/typeof for behavior

**Detection Patterns**:
```
# BAD - Violates OCP (must modify to add new types)
def calculate_area(shape):
    if shape.type == "circle":
        return 3.14 * shape.radius ** 2
    elif shape.type == "rectangle":
        return shape.width * shape.height
    elif shape.type == "triangle":
        return 0.5 * shape.base * shape.height
    # Must add new elif for every new shape!

# GOOD - Follows OCP (extend without modifying)
class Shape(ABC):
    @abstractmethod
    def calculate_area(self): pass

class Circle(Shape):
    def calculate_area(self):
        return 3.14 * self.radius ** 2

class Rectangle(Shape):
    def calculate_area(self):
        return self.width * self.height
```

**Indicators of OCP Violation**:
- Switch/case or if-else chains based on type
- Functions with parameters like `type`, `kind`, `mode` that change behavior
- Frequent modifications to existing classes when adding features

### L - Liskov Substitution Principle (LSP)

**Rule**: Subtypes must be substitutable for their base types without altering correctness.

**Violations to Flag**:
- Subclasses that throw exceptions for inherited methods
- Overridden methods that do nothing or return null
- Subclasses that violate parent class contracts
- Methods that check the concrete type of an object

**Detection Patterns**:
```
# BAD - Violates LSP
class Bird:
    def fly(self): ...

class Penguin(Bird):
    def fly(self):
        raise NotImplementedError("Penguins can't fly!")  # VIOLATION!

# GOOD - Follows LSP
class Bird:
    def move(self): ...

class FlyingBird(Bird):
    def fly(self): ...

class Penguin(Bird):
    def move(self):
        self.swim()
```

**Indicators of LSP Violation**:
- `raise NotImplementedError` in subclass overrides
- Empty method implementations in subclasses
- Type checking before calling methods
- Comments like "not applicable for this subclass"

### I - Interface Segregation Principle (ISP)

**Rule**: Clients should not be forced to depend on interfaces they don't use.

**Violations to Flag**:
- Fat interfaces with many methods
- Classes implementing interfaces with unused methods
- Interfaces that force empty implementations

**Detection Patterns**:
```
# BAD - Fat interface
class IWorker(ABC):
    @abstractmethod
    def work(self): pass
    @abstractmethod
    def eat(self): pass
    @abstractmethod
    def sleep(self): pass

class Robot(IWorker):
    def work(self): ...
    def eat(self): pass  # Robots don't eat - VIOLATION!
    def sleep(self): pass  # Robots don't sleep - VIOLATION!

# GOOD - Segregated interfaces
class IWorkable(ABC):
    @abstractmethod
    def work(self): pass

class IFeedable(ABC):
    @abstractmethod
    def eat(self): pass

class Robot(IWorkable):
    def work(self): ...

class Human(IWorkable, IFeedable):
    def work(self): ...
    def eat(self): ...
```

**Indicators of ISP Violation**:
- Interfaces with more than 5-7 methods
- Classes with `pass` or empty implementations
- Methods that raise `NotImplementedError` for interface methods

### D - Dependency Inversion Principle (DIP)

**Rule**: High-level modules should not depend on low-level modules. Both should depend on abstractions.

**Violations to Flag**:
- Direct instantiation of dependencies inside classes
- High-level modules importing low-level concrete classes
- No dependency injection or inversion of control

**Detection Patterns**:
```
# BAD - High-level depends on low-level
class OrderService:
    def __init__(self):
        self.db = MySQLDatabase()  # Direct dependency - VIOLATION!
        self.mailer = SMTPMailer()  # Direct dependency - VIOLATION!

# GOOD - Depends on abstractions
class OrderService:
    def __init__(self, db: Database, mailer: Mailer):
        self.db = db
        self.mailer = mailer

# Usage with dependency injection
order_service = OrderService(
    db=MySQLDatabase(),
    mailer=SMTPMailer()
)
```

**Indicators of DIP Violation**:
- `new` keyword or direct instantiation inside constructors
- Import of concrete classes in high-level modules
- No constructor parameters for dependencies
- Static method calls for external services

---

## 2. Dead Code Detection - MANDATORY

### Types of Dead Code to Flag

#### Unreachable Code
```
# BAD - Code after return
def process():
    return result
    print("This never executes")  # DEAD CODE!

# BAD - Impossible conditions
if x > 10 and x < 5:  # Impossible condition
    do_something()  # DEAD CODE!
```

#### Unused Variables
```
# BAD
def calculate():
    unused_var = expensive_computation()  # Never used!
    result = other_computation()
    return result
```

#### Unused Functions/Methods
```
# BAD - Function never called anywhere
def legacy_handler():  # No callers in codebase
    pass

# BAD - Private method never used within class
class MyClass:
    def _unused_helper(self):  # Never called
        pass
```

#### Unused Imports
```
# BAD
import os  # Never used
import sys  # Never used
from utils import helper  # Never used

def main():
    print("Hello")
```

#### Unused Parameters
```
# BAD
def process_data(data, unused_param, another_unused):
    return data.transform()  # Parameters never used!
```

#### Commented-Out Code
```
# BAD - Remove, don't comment
def calculate():
    # old_implementation()
    # if legacy_mode:
    #     return legacy_calc()
    return new_implementation()
```

#### Dead Branches
```
# BAD - Feature flags that are always true/false
DEBUG = False
if DEBUG:
    print("Debug info")  # DEAD CODE if DEBUG is always False

# BAD - Redundant conditions
if user.is_admin:
    if user.is_admin:  # Redundant check
        grant_access()
```

### Dead Code Checklist
- [ ] No unreachable code after return/throw/break/continue
- [ ] No unused variables, parameters, or imports
- [ ] No commented-out code blocks
- [ ] No functions/methods with zero callers
- [ ] No impossible conditional branches
- [ ] No redundant null checks or type checks
- [ ] No deprecated code without removal timeline

---

## 3. Code Quality & Readability - MANDATORY

### Naming Conventions

**Rules**:
- Use descriptive, intention-revealing names
- Avoid abbreviations except well-known ones (URL, HTTP, ID)
- Use consistent naming patterns across codebase

**Violations to Flag**:
```
# BAD - Cryptic names
def calc(d, t):
    return d / t

x = get_data()
temp = process(x)
result = transform(temp)

# GOOD - Descriptive names
def calculate_speed(distance_meters, time_seconds):
    return distance_meters / time_seconds

user_records = fetch_user_data()
validated_records = validate_records(user_records)
formatted_output = format_for_display(validated_records)
```

**Naming Conventions by Language**:
- **Python**: `snake_case` for functions/variables, `PascalCase` for classes, `UPPER_SNAKE_CASE` for constants
- **JavaScript/TypeScript**: `camelCase` for functions/variables, `PascalCase` for classes/components, `UPPER_SNAKE_CASE` for constants
- **Java/Kotlin**: `camelCase` for methods/variables, `PascalCase` for classes, `UPPER_SNAKE_CASE` for constants
- **Go**: `camelCase` for private, `PascalCase` for exported, acronyms in caps (HTTPServer)

### Function/Method Quality

**Rules**:
- Functions should do ONE thing
- Maximum 20-30 lines per function (prefer 10-15)
- Maximum 3-4 parameters (use objects for more)
- No side effects in functions that return values
- Consistent abstraction level within function

**Violations to Flag**:
```
# BAD - Too many parameters
def create_user(name, email, age, address, phone, department, role, manager, start_date, salary):
    ...

# GOOD - Use parameter object
@dataclass
class UserCreationRequest:
    name: str
    email: str
    age: int
    # ... other fields

def create_user(request: UserCreationRequest):
    ...

# BAD - Mixed abstraction levels
def process_order(order):
    # High level
    validate_order(order)

    # Suddenly low level - VIOLATION!
    connection = db.connect()
    cursor = connection.cursor()
    cursor.execute("INSERT INTO orders ...")
    connection.commit()

    # Back to high level
    send_confirmation(order)

# GOOD - Consistent abstraction
def process_order(order):
    validate_order(order)
    save_order(order)
    send_confirmation(order)
```

### Code Complexity

**Rules**:
- Cyclomatic complexity should be < 10 per function
- Maximum nesting depth of 3-4 levels
- Avoid deeply nested callbacks (callback hell)

**Violations to Flag**:
```
# BAD - Deep nesting
def process(data):
    if data:
        if data.is_valid:
            if data.user:
                if data.user.is_active:
                    if data.user.has_permission:
                        # Finally doing something at level 5!
                        return process_data(data)

# GOOD - Early returns (guard clauses)
def process(data):
    if not data:
        return None
    if not data.is_valid:
        return None
    if not data.user:
        return None
    if not data.user.is_active:
        return None
    if not data.user.has_permission:
        return None

    return process_data(data)

# BETTER - Combined checks
def process(data):
    if not is_processable(data):
        return None
    return process_data(data)

def is_processable(data):
    return (data and
            data.is_valid and
            data.user and
            data.user.is_active and
            data.user.has_permission)
```

### Magic Numbers and Strings

**Rule**: Extract magic values to named constants.

```
# BAD - Magic numbers
if user.age >= 18:
    if retry_count < 3:
        sleep(86400)

# GOOD - Named constants
MINIMUM_ADULT_AGE = 18
MAX_RETRY_ATTEMPTS = 3
SECONDS_PER_DAY = 86400

if user.age >= MINIMUM_ADULT_AGE:
    if retry_count < MAX_RETRY_ATTEMPTS:
        sleep(SECONDS_PER_DAY)
```

### Comments Quality

**Rules**:
- Code should be self-documenting; comments explain WHY, not WHAT
- Remove outdated/misleading comments
- No commented-out code
- Use docstrings for public APIs

```
# BAD - Explains what (obvious from code)
# Increment counter by 1
counter += 1

# Iterate through users
for user in users:
    process(user)

# GOOD - Explains why (not obvious)
# Using binary search because dataset exceeds 1M records
# and linear search caused timeout issues (see incident #1234)
index = binary_search(sorted_data, target)

# Retry with exponential backoff to handle rate limiting
# from third-party API (max 100 requests/minute)
for attempt in range(MAX_RETRIES):
    ...
```

---

## 4. Modularity & Architecture - MANDATORY

### Module Cohesion

**Rule**: Keep related code together; separate unrelated code.

**Violations to Flag**:
- Utility classes with unrelated methods
- Modules mixing different domains
- Circular dependencies between modules

```
# BAD - Low cohesion utility class
class Utils:
    @staticmethod
    def format_date(date): ...
    @staticmethod
    def calculate_tax(amount): ...
    @staticmethod
    def send_email(to, body): ...
    @staticmethod
    def compress_image(image): ...

# GOOD - High cohesion modules
class DateFormatter:
    def format(self, date): ...
    def parse(self, date_string): ...

class TaxCalculator:
    def calculate(self, amount): ...
    def apply_discount(self, amount, discount): ...
```

### Module Coupling

**Rule**: Minimize dependencies between modules.

**Violations to Flag**:
- Tight coupling through direct instantiation
- Feature envy (class uses another class's data excessively)
- Law of Demeter violations (train wrecks)

```
# BAD - Law of Demeter violation (train wreck)
user.get_department().get_manager().get_email().send(message)

# GOOD - Tell, don't ask
user.notify_manager(message)

# BAD - Feature envy
class OrderPrinter:
    def print_order(self, order):
        print(f"Customer: {order.customer.name}")
        print(f"Address: {order.customer.address.street}, {order.customer.address.city}")
        print(f"Total: {order.items.sum(lambda i: i.price * i.quantity)}")

# GOOD - Behavior belongs with data
class Order:
    def get_summary(self):
        return {
            'customer': self.customer.get_contact_info(),
            'total': self.calculate_total()
        }
```

### File/Module Size

**Guidelines**:
- Single file should not exceed 300-500 lines
- Single class should not exceed 200-300 lines
- Single function should not exceed 20-30 lines
- If larger, refactor into smaller modules

### Package/Directory Structure

**Rules**:
- Organize by feature/domain, not by type
- Clear separation of concerns
- Consistent structure across codebase

```
# BAD - Organized by type
/controllers
    user_controller.py
    order_controller.py
    product_controller.py
/models
    user.py
    order.py
    product.py
/services
    user_service.py
    order_service.py
    product_service.py

# GOOD - Organized by feature/domain
/users
    user.py
    user_service.py
    user_controller.py
    user_repository.py
/orders
    order.py
    order_service.py
    order_controller.py
    order_repository.py
```

---

## 5. Code Smells to Detect - MANDATORY

### Bloaters
- [ ] **Long Method**: Function > 20-30 lines
- [ ] **Large Class**: Class > 200-300 lines or > 10 methods
- [ ] **Long Parameter List**: Function with > 4 parameters
- [ ] **Data Clumps**: Groups of variables that appear together repeatedly
- [ ] **Primitive Obsession**: Using primitives instead of small objects

### Object-Orientation Abusers
- [ ] **Switch Statements**: Type-checking switch/if-else chains
- [ ] **Parallel Inheritance Hierarchies**: Adding to one requires adding to another
- [ ] **Refused Bequest**: Subclass doesn't use parent's methods
- [ ] **Alternative Classes with Different Interfaces**: Similar classes, different method names

### Change Preventers
- [ ] **Divergent Change**: One class changed for multiple reasons
- [ ] **Shotgun Surgery**: One change requires modifying many classes
- [ ] **Parallel Inheritance**: Subclassing one class requires subclassing another

### Dispensables
- [ ] **Comments**: Excessive comments indicating unclear code
- [ ] **Duplicate Code**: Same code in multiple places (DRY violation)
- [ ] **Dead Code**: Unreachable or unused code
- [ ] **Lazy Class**: Class that doesn't do enough
- [ ] **Speculative Generality**: Unused abstractions "for the future"

### Couplers
- [ ] **Feature Envy**: Method uses another class's data excessively
- [ ] **Inappropriate Intimacy**: Classes that are too tightly coupled
- [ ] **Message Chains**: Long chains of method calls (a.b().c().d())
- [ ] **Middle Man**: Class that only delegates to another class

---

## 6. Refactoring Recommendations

### When to Refactor

**Mandatory Refactoring Triggers**:
- Rule of Three: Duplicated code appears third time
- Adding feature is difficult due to current structure
- Bug fixes keep appearing in same area
- Code review identifies multiple code smells
- New team members struggle to understand code

### Common Refactoring Patterns

#### Extract Method
```
# Before
def print_invoice(invoice):
    print("=" * 40)
    print(f"Invoice #{invoice.id}")
    print("=" * 40)
    total = 0
    for item in invoice.items:
        print(f"{item.name}: ${item.price}")
        total += item.price
    print("-" * 40)
    print(f"Total: ${total}")

# After
def print_invoice(invoice):
    print_header(invoice)
    print_line_items(invoice.items)
    print_total(calculate_total(invoice.items))
```

#### Extract Class
```
# Before - Class doing too much
class Order:
    def __init__(self):
        self.customer_name = ""
        self.customer_email = ""
        self.customer_address = ""
        self.items = []

    def send_confirmation_email(self): ...
    def validate_customer_email(self): ...

# After - Extracted Customer class
class Customer:
    def __init__(self, name, email, address):
        self.name = name
        self.email = email
        self.address = address

    def validate_email(self): ...

class Order:
    def __init__(self, customer: Customer):
        self.customer = customer
        self.items = []
```

#### Replace Conditional with Polymorphism
```
# Before
def get_speed(vehicle):
    if vehicle.type == "car":
        return vehicle.engine_power / vehicle.weight
    elif vehicle.type == "bicycle":
        return vehicle.gear_ratio * vehicle.pedal_speed
    elif vehicle.type == "boat":
        return vehicle.engine_power / vehicle.water_resistance

# After
class Vehicle(ABC):
    @abstractmethod
    def get_speed(self): pass

class Car(Vehicle):
    def get_speed(self):
        return self.engine_power / self.weight

class Bicycle(Vehicle):
    def get_speed(self):
        return self.gear_ratio * self.pedal_speed
```

---

## 7. Implementation Checklist

### Pre-Code Review (Developer)
- [ ] All functions have single responsibility
- [ ] No function exceeds 30 lines
- [ ] No class exceeds 300 lines
- [ ] No file exceeds 500 lines
- [ ] Maximum 4 parameters per function
- [ ] No magic numbers or strings
- [ ] All variables and functions have descriptive names
- [ ] No dead code (unused variables, functions, imports)
- [ ] No commented-out code
- [ ] Maximum nesting depth of 3 levels
- [ ] Dependencies injected, not instantiated internally
- [ ] No code duplication (DRY)

### Code Review (Reviewer)
- [ ] **SRP**: Each class/function has single responsibility
- [ ] **OCP**: New features can be added without modifying existing code
- [ ] **LSP**: Subclasses can replace parent classes
- [ ] **ISP**: No fat interfaces forcing empty implementations
- [ ] **DIP**: High-level modules depend on abstractions
- [ ] **Dead Code**: No unreachable or unused code
- [ ] **Readability**: Code is self-documenting
- [ ] **Modularity**: High cohesion, low coupling
- [ ] **Complexity**: Cyclomatic complexity < 10 per function

### Automated Checks (CI/CD)
- [ ] Linting rules enforced (ESLint, Pylint, etc.)
- [ ] Complexity analysis (cyclomatic, cognitive)
- [ ] Dead code detection (unused exports, functions)
- [ ] Duplicate code detection
- [ ] Import analysis (circular, unused)
- [ ] Test coverage for critical paths

---

## 8. Language-Specific Tools

### Python
- `pylint` - Comprehensive linting
- `flake8` - Style guide enforcement
- `mypy` - Static type checking
- `vulture` - Dead code detection
- `radon` - Complexity metrics
- `bandit` - Security linting

### JavaScript/TypeScript
- `eslint` - Linting with SOLID plugins
- `typescript` - Static type checking
- `ts-unused-exports` - Dead export detection
- `madge` - Circular dependency detection
- `complexity-report` - Complexity metrics

### Java
- `SonarQube` - Comprehensive analysis
- `PMD` - Dead code, complexity
- `SpotBugs` - Bug patterns
- `Checkstyle` - Style enforcement

### Go
- `golangci-lint` - Meta linter
- `staticcheck` - Static analysis
- `unused` - Unused code detection
- `gocyclo` - Complexity

### General
- `SonarQube` - Multi-language support
- `CodeClimate` - Quality metrics
- `Codacy` - Automated reviews

---

You must always explain how this rule was applied and why it was applied when reviewing code.
