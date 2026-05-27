#!/usr/bin/env python3
import subprocess
import random

# Color constants for terminal output
GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"

def run_binary(args=None, stdin_data=None):
    """Executes the ./multi binary with optional flags and stdin input."""
    cmd = ["./multi"]
    if args:
        cmd.extend(args)
    
    try:
        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate(input=stdin_data, timeout=2)
        return stdout.strip().split('\n'), stderr.strip(), process.returncode
    except subprocess.TimeoutExpired:
        process.kill()
        return [], "TIMEOUT EXPIRED", -1
    except FileNotFoundError:
        return [], "Executable './multi' not found. Did you run make?", -1

def assert_test(test_name, condition, details=""):
    """Prints a structured pass/fail log line."""
    if condition:
        print(f"[{GREEN}PASS{RESET}] {test_name}")
    else:
        print(f"[{RED}FAIL{RESET}] {test_name}")
        if details:
            print(f"       -> {details}")

# =============================================================================
# 1. DEFAULT RUN TESTS (Part 1.A & Part 2 Default Configuration)
# =============================================================================
print("--- Running Default Config Tests ---")
stdout, stderr, code = run_binary()

if code != 0:
    assert_test("Default Execution", False, f"Exit code {code}. Stderr: {stderr}")
else:
    assert_test("Default Execution Exit Code", code == 0)
    
    # Expected default output values based on the assignment documentation
    expected_x = "4f440201aa"
    expected_y = "4f44030201aa"
    expected_sum = "4f9347040354"
    
    if len(stdout) >= 3:
        # Some implementations might keep leading zeros, so we strip them for absolute numerical equivalence
        val_x = int(stdout[0], 16)
        val_y = int(stdout[1], 16)
        val_sum = int(stdout[2], 16)
        
        assert_test("Default: X Value Match", val_x == int(expected_x, 16), f"Got: {stdout[0]}")
        assert_test("Default: Y Value Match", val_y == int(expected_y, 16), f"Got: {stdout[1]}")
        assert_test("Default: Sum Value Match", val_sum == int(expected_sum, 16), f"Got: {stdout[2]}")
    else:
        assert_test("Default Outputs Format", False, f"Expected 3 lines of output, got {len(stdout)}")

print()

# =============================================================================
# 2. INTERACTIVE MODE TESTS (-I Flag / Part 1.B & Part 2)
# =============================================================================
print("--- Running Interactive Mode Tests (-I) ---")

def test_interactive_pair(hex1, hex2, test_label):
    """Helper to push two hex strings into stdin and verify the addition."""
    stdin_payload = f"{hex1}\n{hex2}\n"
    stdout, stderr, code = run_binary(args=["-I"], stdin_data=stdin_payload)
    
    if code != 0 or len(stdout) < 3:
        assert_test(test_label, False, f"Execution failed. Output: {stdout}, Stderr: {stderr}")
        return

    # Treat empty strings or invalid inputs gracefully as numerical 0
    val1 = int(hex1, 16) if hex1.strip() else 0
    val2 = int(hex2, 16) if hex2.strip() else 0
    expected_sum = val1 + val2

    out_val1 = int(stdout[0], 16)
    out_val2 = int(stdout[1], 16)
    out_val_sum = int(stdout[2], 16)

    success = (out_val1 == val1) and (out_val2 == val2) and (out_val_sum == expected_sum)
    details = f"In: {hex1} + {hex2} | Expected sum: {hex(expected_sum)} | Got: {stdout[2]}"
    assert_test(test_label, success, details if not success else "")

# Test Case 2.1: Small standard values
test_interactive_pair("2", "1", "Simple Addition (2 + 1)")

# Test Case 2.2: Large matching inputs (Assignment example)
large_f = "f" * 71
test_interactive_pair(large_f, "1", "Large Int Overflow Propagation")

# Test Case 2.3: Odd character string sizes (verifies padding behavior from Part 1.B)
test_interactive_pair("a", "b", "Odd Length Strings String Handlers (1 hex character)")
test_interactive_pair("123", "45678", "Mismatched Odd/Even Character Constraints")

# Test Case 2.4: Substantial payload data vectors (close to 500 characters limit)
huge_1 = "a" * 400
huge_2 = "b" * 400
test_interactive_pair(huge_1, huge_2, "Stress Test: 400 Characters Width Payload")

print()

# =============================================================================
# 3. RANDOM MODE TESTS (-R Flag / Part 3)
# =============================================================================
print("--- Running Pseudo-Random Mode Tests (-R) ---")
stdout, stderr, code = run_binary(args=["-R"])

if code != 0:
    assert_test("Random Execution", False, f"Exit code {code}. Stderr: {stderr}")
else:
    assert_test("Random Execution Exit Code", code == 0)
    
    if len(stdout) == 3:
        try:
            r_val1 = int(stdout[0], 16)
            r_val2 = int(stdout[1], 16)
            r_sum  = int(stdout[2], 16)
            
            # Mathematical validation: does R_Val1 + R_Val2 == R_Sum?
            math_check = (r_val1 + r_val2) == r_sum
            assert_test("Random Addition Mathematical Integrity", math_check, 
                        f"Parsed: {hex(r_val1)} + {hex(r_val2)} = {hex(r_sum)}")
            
            # Uniqueness check: Ensure numbers generated aren't zero or hardcoded stubs
            assert_test("Random Non-Trivial Generation", r_val1 != 0 and r_val2 != 0)
            
        except ValueError:
            assert_test("Random Output Hex Validation", False, "Output lines were not valid hex integers.")
    else:
        assert_test("Random Output Format", False, f"Expected 3 lines, got {len(stdout)}")

print()
print("--- Testing Sequence Finalized ---")