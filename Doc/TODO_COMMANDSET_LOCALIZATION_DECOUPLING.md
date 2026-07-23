# ⚠️ TECHNICAL DEBT / TODO: CommandSet Localization Decoupling (DI Refactor)

**Status:** To Do
**Priority:** High
**Affected Component(s):** `Sezam.Commands.CommandSet`, `Console/Session.cs` (initialization logic), `Data.Store.cs` (service wiring).
**Goal:** Eliminate brittle, reflection-based initialization of localization resources within the `CommandSet` constructor and replace it with Dependency Injection (DI) for robust architecture.

### ⚙️ The Problem
The current implementation uses reflection (`GetType().GetCustomAttribute`, accessing private static fields via `System.Reflection.BindingFlags`) to find and initialize the `ResourceManager` inside the `CommandSet` constructor. This approach is:
1.  **Brittle:** It tightly couples `CommandSet` to the internal, non-public structure of the project's resource files (`*.strings`). Any rename or refactor in the build process could break this silently.
2.  **Untestable:** The initialization logic is difficult to unit test because it relies on global state and runtime reflection magic.

### ✅ Proposed Solution (DI Pattern)
1.  **Define Interface:** Create an `ILocalizationService` interface that abstracts the localization mechanism (`string GetString(string key, CultureInfo culture)`).
2.  **Concrete Implementation:** Implement a concrete class (e.g., `ResourceManagerLocalizationService`) that handles the actual reflection/resource loading internally but adheres to the `ILocalizationService` contract. This isolates the fragile code.
3.  **Refactor CommandSet Constructor:** Update `CommandSet(Session session)` to accept `ILocalizationService localizationService` as a required parameter in its constructor, rather than initializing it itself via reflection.
4.  **Wiring:** The main application startup point (`Program.cs` or equivalent service provider setup) must be updated to:
    a. Instantiate the resource manager.
    b. Pass the resource manager into `ResourceManagerLocalizationService`.
    c. Register and pass the resulting `ILocalizationService` instance when creating any new `CommandSet` instances.

### 📝 Impact & Review Checklist
*   [ ] Update `CommandSet` constructor signature to accept `ILocalizationService`.
*   [ ] Remove all reflection code related to resource loading from `CommandSet`.
*   [ ] Create and test the `ILocalizationService` abstraction layer.
*   [ ] Update all calling points (e.g., root command set creation) to pass the dependency.

**Rationale:** This change improves modularity, significantly increases testability, and future-proofs the core command logic against internal resource file structure changes.