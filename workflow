Yes — here is the **updated end-to-end flow** based on the **latest understanding**:

* **Supervisor sits on top as the control authority**
* **Planner owns plan generation and replanning**
* **Orchestrator owns execution mechanics**
* **Governance and Memory remain external services/layers**

# Updated flow with latest Supervisor–Planner–Orchestrator model

1. **Request Intake receives the user request**
   Intake validates, normalizes, enriches metadata, and creates the initial `RequestEnvelope`.

2. **Request Intake calls Governance: `evaluate_request_policy()`**
   Governance returns request-level constraints such as role, tenant, risk class, allowed workflow type, and baseline control envelope.

3. **Supervisor performs request assessment / intent understanding**
   Supervisor acts as the top control authority and interprets:

   * request type
   * workflow family
   * complexity / ambiguity
   * control sensitivity

4. **Supervisor calls Memory: `query_memory()` / `search_semantic_context()` for decision-support context**
   It may retrieve:

   * similar prior request patterns
   * relevant procedural templates
   * escalation / control precedents
   * domain/policy context

5. **Supervisor selects planning strategy / control envelope**
   Supervisor determines:

   * which planning mode/template should be used
   * what control/risk/budget envelope applies
   * whether special approval or evidence sensitivity is needed

6. **Planner receives the normalized request + supervisory control envelope**
   Planner does not start from raw request alone anymore; it starts from:

   * `RequestEnvelope`
   * supervisory request assessment
   * planning strategy
   * control constraints

7. **Planner calls Memory: `query_memory()` + `search_semantic_context()`**
   Planner retrieves:

   * procedural templates / playbooks
   * semantic knowledge / evidence sources
   * similar episodic planning patterns

8. **Planner generates candidate `ExecutionPlan`**
   Planner’s planning engine decomposes the request into:

   * `TaskNode`s
   * dependencies
   * evidence requirements
   * execution metadata

9. **Planner validates and normalizes the plan**
   Dynamic plan validation and constraint enforcement ensure:

   * executable structure
   * valid dependencies
   * required metadata
   * runtime feasibility

10. **Planner calls Governance: `evaluate_plan_policy()`**
    Governance evaluates whether the generated plan is acceptable under current policy/risk constraints.

11. **Planner writes plan artifact / plan lineage metadata to Memory**
    Planner stores:

* plan version
* plan summary
* planning metadata
* replan lineage context if applicable

12. **Orchestrator loads the approved `ExecutionPlan`**
    Orchestrator becomes the runtime owner of execution.

13. **Orchestrator schedules ready `TaskNode`s**
    Scheduler + dependency resolver determine which nodes are executable now.

14. **Orchestrator may call Memory for execution context**
    It retrieves:

* prior node outputs
* execution hints
* fallback/recovery patterns
* procedural runtime guidance

15. **Dispatcher calls Governance: `authorize_tool_call()`**
    Before invoking a tool / MCP tool / API / agent, the dispatcher checks whether that action is allowed.

16. **If authorized, Dispatcher executes the tool / agent / API**
    Orchestrator manages runtime execution, not the Supervisor.

17. **Orchestrator writes `StateCheckpoint` / runtime state to Memory (and trace systems)**
    This includes:

* task status
* outputs
* retry count
* evidence refs
* runtime metadata

18. **Supervisor reads checkpoints / run history / relevant memory context**
    Supervisor uses:

* latest `StateCheckpoint`
* prior failure patterns
* policy/risk guidance
* supervisory decision-support memory

19. **Supervisor calls Governance: `evaluate_supervisor_decision()`**
    Governance checks whether the proposed supervisory action is permitted under policy and risk thresholds.

20. **Supervisor decides: continue / retry-escalation / replan / escalate / stop**
    Important split:

* **Orchestrator** owns local bounded retry execution
* **Supervisor** decides when retries are no longer enough and whether to replan/escalate/stop

21. **If decision = continue**
    Orchestrator proceeds with next ready task.

22. **If decision = bounded retry**
    Orchestrator performs retry within allowed runtime limits.

23. **If decision = replan**
    Supervisor creates `ReplanRequest` with:

* failure context
* current checkpoint state
* control constraints
* reason for replanning

24. **Planner reads Memory again and generates revised plan**
    Planner uses:

* current partial execution state
* prior episodic patterns
* semantic/procedural context
* supervisory replan constraints

25. **Updated plan returns to Orchestrator and execution resumes**
    Orchestrator loads the new plan version and continues.

26. **If decision = escalate or stop**
    Supervisor emits escalation/stop artifacts, and Orchestrator transitions the run into hold, stop, or handoff state.

---

# Clean role summary in this updated flow

## Supervisor

* request assessment / intent understanding
* planning strategy selection
* control envelope definition
* runtime intervention decisions

## Planner

* actual plan generation
* plan validation/normalization
* replanning

## Orchestrator

* execution
* scheduling
* dispatch
* state/checkpoint management
* bounded retries

---

# Shorter version for documentation

**Updated control flow:**
Request Intake first normalizes and enriches the request, then Governance evaluates request-level policy. The Supervisor performs request assessment, selects planning strategy and control envelope, and passes those into the Planner. The Planner retrieves relevant memory context, generates and validates the `ExecutionPlan`, and submits it for plan-level governance review before writing plan artifacts to memory. The Orchestrator then loads the approved plan, schedules tasks, retrieves execution context from memory when needed, authorizes tool calls through Governance, executes tasks, and writes `StateCheckpoint`s. The Supervisor continuously reads checkpoints and decision-support memory, evaluates runtime state against governance rules, and decides whether to continue, retry, replan, escalate, or stop. If replanning is needed, the Supervisor creates a `ReplanRequest`, and the Planner reads memory again to generate an updated plan for the Orchestrator to resume execution.**

If you want, I can convert this into a **diagram-ready sequence format** next.
