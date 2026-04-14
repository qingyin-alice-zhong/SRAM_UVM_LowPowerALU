# Low-Power Verification Notes

This note captures the concrete low-power verification requirements for the SRAM project.

## Scope and Assumptions

- Low-power control signal under verification: `sleep_i`
- Interface protocol context: AHB-Lite style pipelined transfers
- Behavioral expectation in current DUT model:
  - Reads during sleep return `0`
  - Writes during sleep are blocked (no memory update)
  - Normal access resumes after sleep deassertion

## Functional Requirements

1. Sleep Entry Behavior
- When `sleep_i` is asserted, the DUT transitions to sleep behavior without producing protocol-unsafe outputs.

2. Read Behavior in Sleep
- Any read accepted while `sleep_i=1` must return `32'h0000_0000`.

3. Write Behavior in Sleep
- Any write accepted while `sleep_i=1` must not change SRAM model contents.

4. Wake-Up Behavior
- After `sleep_i` deassertion, accesses return to normal operation.
- Data written before sleep remains readable after wake-up.

5. Sleep During Active Transfer Window
- If sleep is asserted near an in-flight transfer window, DUT behavior must still follow the model expectations above (no illegal corruption / deterministic read result policy).

## Test Mapping

- `low_power_sleep_entry_test`
  - Covers sleep entry, read-zero during sleep, and post-wakeup visibility.

- `low_power_sleep_blocks_write_test`
  - Covers write blocking during sleep and post-wakeup data integrity.

- `low_power_sleep_pipeline_interrupt_test`
  - Covers sleep assertion around an active transfer timing window.

## Scoreboard Rules (Implemented)

- If sampled transaction has `sleep_state=1`:
  - Write: no reference memory update; treat as expected blocked write.
  - Read: expected data is `32'h0000_0000`.

- If sampled transaction has `sleep_state=0`:
  - Apply normal masked write and read-compare rules.

## Coverage Expectations (Implemented)

- Coverpoints include:
  - sleep state (`awake`, `sleep`)
  - transfer direction (`read`, `write`)
  - transfer size (`byte`, `half`, `word`)
  - alignment (`addr[1:0]`)

- Key crosses include:
  - sleep × read/write × size
  - sleep × read/write × alignment

## Pass Criteria (Low-Power)

- No scoreboard mismatch for all low-power tests.
- No assertion failures in low-power runs.
- Low-power functional coverpoints/crosses show hits for intended sleep scenarios.
- Regression includes all low-power tests in `sim/regression.list`.

## Open Items

- Run-time validation pending local simulator setup (`vlib/vlog/vsim` + `UVM_HOME`).
- If spec evolves, update this note first, then align tests/scoreboard/coverage.
