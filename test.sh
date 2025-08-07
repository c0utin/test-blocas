#!/bin/bash

# BLOCAS DeFi Ecosystem - Comprehensive Testing Script
# This script runs all tests, builds contracts, and provides detailed reporting

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for better visual feedback
SUCCESS="✅"
FAILURE="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
GEAR="⚙️"
TEST="🧪"
BUILD="🔨"

# Script configuration
VERBOSE=false
COVERAGE=false
GAS_REPORT=false
CLEAN_BUILD=false
RUN_DEMO=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -c|--coverage)
      COVERAGE=true
      shift
      ;;
    -g|--gas)
      GAS_REPORT=true
      shift
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --demo)
      RUN_DEMO=true
      shift
      ;;
    -h|--help)
      echo "BLOCAS DeFi Testing Script"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -v, --verbose    Run tests with verbose output"
      echo "  -c, --coverage   Generate test coverage report"
      echo "  -g, --gas        Generate gas usage report"
      echo "  --clean          Clean build artifacts before testing"
      echo "  --demo           Run demo script after tests"
      echo "  -h, --help       Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                    # Run all tests with standard output"
      echo "  $0 -v -g             # Run tests with verbose output and gas report"
      echo "  $0 --clean --demo    # Clean build, test, and run demo"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      echo "Use $0 --help for usage information"
      exit 1
      ;;
  esac
done

# Function to print colored output
print_status() {
  local status=$1
  local message=$2
  local color=$3
  echo -e "${color}${status} ${message}${NC}"
}

print_header() {
  local message=$1
  echo ""
  echo -e "${CYAN}================================${NC}"
  echo -e "${CYAN}${message}${NC}"
  echo -e "${CYAN}================================${NC}"
}

print_section() {
  local message=$1
  echo ""
  echo -e "${BLUE}--- ${message} ---${NC}"
}

# Function to check if we're in a Nix development environment
check_nix_env() {
  # Check multiple possible Nix environment indicators
  if [[ -n "$NIX_SHELL" ]] || [[ -n "$IN_NIX_SHELL" ]] || [[ "$SHLVL" -gt 1 && -n "$NIX_PATH" ]]; then
    print_status "$SUCCESS" "Nix development environment detected" "$GREEN"
  else
    print_status "$WARNING" "Not in Nix development environment" "$YELLOW"
    print_status "$INFO" "Run 'nix develop' first for best results" "$CYAN"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  fi
}

# Function to check if required tools are available
check_dependencies() {
  print_section "Checking Dependencies"
  
  local missing_deps=0
  
  if ! command -v forge &> /dev/null; then
    print_status "$FAILURE" "forge not found" "$RED"
    ((missing_deps++))
  else
    print_status "$SUCCESS" "forge found: $(forge --version | head -n1)" "$GREEN"
  fi
  
  if ! command -v cast &> /dev/null; then
    print_status "$FAILURE" "cast not found" "$RED"
    ((missing_deps++))
  else
    print_status "$SUCCESS" "cast found" "$GREEN"
  fi
  
  if [[ $missing_deps -gt 0 ]]; then
    print_status "$FAILURE" "$missing_deps missing dependencies" "$RED"
    exit 1
  fi
}

# Function to clean build artifacts
clean_build() {
  if [[ "$CLEAN_BUILD" == true ]]; then
    print_section "Cleaning Build Artifacts"
    
    if [[ -d "out" ]]; then
      rm -rf out
      print_status "$SUCCESS" "Removed out/ directory" "$GREEN"
    fi
    
    if [[ -d "cache" ]]; then
      rm -rf cache
      print_status "$SUCCESS" "Removed cache/ directory" "$GREEN"
    fi
    
    if [[ -f "foundry.lock" ]]; then
      rm foundry.lock
      print_status "$SUCCESS" "Removed foundry.lock" "$GREEN"
    fi
  fi
}

# Function to build contracts
build_contracts() {
  print_section "Building Contracts"
  
  print_status "$BUILD" "Compiling smart contracts..." "$BLUE"
  
  if forge build; then
    print_status "$SUCCESS" "All contracts compiled successfully" "$GREEN"
    
    # Count compiled contracts
    local contract_count=$(find out -name "*.json" -not -path "*/build-info/*" | wc -l)
    print_status "$INFO" "Compiled $contract_count contract artifacts" "$CYAN"
  else
    print_status "$FAILURE" "Contract compilation failed" "$RED"
    exit 1
  fi
}

# Function to run tests
run_tests() {
  print_section "Running Tests"
  
  local test_args=""
  
  if [[ "$VERBOSE" == true ]]; then
    test_args="$test_args -vvv"
  fi
  
  if [[ "$GAS_REPORT" == true ]]; then
    test_args="$test_args --gas-report"
  fi
  
  print_status "$TEST" "Running comprehensive test suite..." "$BLUE"
  
  if [[ "$VERBOSE" == true ]]; then
    print_status "$INFO" "Running with verbose output" "$CYAN"
  fi
  
  # Run all tests
  if forge test $test_args; then
    print_status "$SUCCESS" "All tests passed!" "$GREEN"
  else
    print_status "$FAILURE" "Some tests failed" "$RED"
    exit 1
  fi
}

# Function to run individual test suites
run_individual_tests() {
  print_section "Individual Test Suites"
  
  local test_contracts=("WrappedDAITest" "DebentureTest" "DAOGovernanceTest")
  local passed_suites=0
  local total_suites=${#test_contracts[@]}
  
  for contract in "${test_contracts[@]}"; do
    print_status "$TEST" "Running $contract..." "$BLUE"
    
    if forge test --match-contract "$contract"; then
      print_status "$SUCCESS" "$contract passed" "$GREEN"
      ((passed_suites++))
    else
      print_status "$FAILURE" "$contract failed" "$RED"
    fi
  done
  
  print_status "$INFO" "$passed_suites/$total_suites test suites passed" "$CYAN"
}

# Function to generate coverage report
generate_coverage() {
  if [[ "$COVERAGE" == true ]]; then
    print_section "Generating Coverage Report"
    
    print_status "$INFO" "Running coverage analysis..." "$CYAN"
    
    if command -v lcov &> /dev/null; then
      forge coverage --report lcov
      
      if [[ -f "lcov.info" ]]; then
        print_status "$SUCCESS" "Coverage report generated: lcov.info" "$GREEN"
        
        # Generate HTML report if genhtml is available
        if command -v genhtml &> /dev/null; then
          genhtml lcov.info -o coverage/
          print_status "$SUCCESS" "HTML coverage report: coverage/index.html" "$GREEN"
        fi
      fi
    else
      # Fallback to basic coverage
      forge coverage
      print_status "$INFO" "Install lcov for detailed coverage reports" "$CYAN"
    fi
  fi
}

# Function to run gas benchmarks
run_gas_benchmarks() {
  if [[ "$GAS_REPORT" == true ]]; then
    print_section "Gas Usage Analysis"
    
    print_status "$GEAR" "Analyzing gas usage..." "$BLUE"
    
    # Run specific gas-heavy operations
    forge test --gas-report --match-test "testFuzz" > gas_report.txt 2>&1 || true
    
    if [[ -f "gas_report.txt" ]]; then
      print_status "$SUCCESS" "Gas report saved to gas_report.txt" "$GREEN"
      
      # Show summary
      echo ""
      echo -e "${PURPLE}Gas Usage Summary:${NC}"
      grep -E "(│.*│.*│.*│)" gas_report.txt | head -10 || echo "No gas data found"
    fi
  fi
}

# Function to run demo script
run_demo() {
  if [[ "$RUN_DEMO" == true ]]; then
    print_section "Running Demo Script"
    
    print_status "$ROCKET" "Executing demo script..." "$BLUE"
    
    if forge script script/Demo.s.sol; then
      print_status "$SUCCESS" "Demo script completed successfully" "$GREEN"
    else
      print_status "$FAILURE" "Demo script failed" "$RED"
    fi
  fi
}

# Function to generate test summary
generate_summary() {
  print_header "TEST SUMMARY"
  
  # Count test files and functions
  local test_files=$(find test -name "*.t.sol" | wc -l)
  local test_functions=$(grep -r "function test" test/ | wc -l)
  
  # Count contracts
  local src_files=$(find src -name "*.sol" | wc -l)
  
  # Check if build artifacts exist
  local compiled_contracts=0
  if [[ -d "out" ]]; then
    compiled_contracts=$(find out -name "*.json" -not -path "*/build-info/*" | wc -l)
  fi
  
  echo -e "${GREEN}📊 Project Statistics:${NC}"
  echo -e "   ${CYAN}📁 Source Files:${NC} $src_files contracts"
  echo -e "   ${CYAN}🧪 Test Files:${NC} $test_files test files"
  echo -e "   ${CYAN}🔬 Test Functions:${NC} $test_functions test functions"
  echo -e "   ${CYAN}⚙️ Compiled Artifacts:${NC} $compiled_contracts artifacts"
  
  echo ""
  echo -e "${GREEN}✅ All Tests Completed Successfully!${NC}"
  echo ""
  echo -e "${PURPLE}🎯 BLOCAS DeFi Ecosystem - Ready for Production${NC}"
  
  # Show quick commands
  echo ""
  echo -e "${YELLOW}Quick Commands:${NC}"
  echo -e "   ${CYAN}Build:${NC}        forge build"
  echo -e "   ${CYAN}Test:${NC}         forge test"
  echo -e "   ${CYAN}Deploy:${NC}       forge script script/Deploy.s.sol"
  echo -e "   ${CYAN}Demo:${NC}         forge script script/Demo.s.sol"
}

# Main execution flow
main() {
  print_header "$ROCKET BLOCAS DeFi Ecosystem - Testing Suite"
  
  echo -e "${PURPLE}Comprehensive testing for production-ready DeFi contracts${NC}"
  echo ""
  
  # Show configuration
  echo -e "${YELLOW}Configuration:${NC}"
  echo -e "   Verbose: $VERBOSE"
  echo -e "   Coverage: $COVERAGE"
  echo -e "   Gas Report: $GAS_REPORT"
  echo -e "   Clean Build: $CLEAN_BUILD"
  echo -e "   Run Demo: $RUN_DEMO"
  
  # Execute testing pipeline
  check_nix_env
  check_dependencies
  clean_build
  build_contracts
  run_tests
  run_individual_tests
  generate_coverage
  run_gas_benchmarks
  run_demo
  generate_summary
  
  print_status "$SUCCESS" "Testing pipeline completed successfully!" "$GREEN"
}

# Run main function
main "$@" 