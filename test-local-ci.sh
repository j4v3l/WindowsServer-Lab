#!/bin/bash

# Local CI/CD test script for macOS/Linux
# Tests file structure, documentation, and GitHub templates

set -e

echo "🔍 Starting Local CI/CD Validation (Bash Version)..."
echo "================================================"

# Track overall success
OVERALL_SUCCESS=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
  OVERALL_SUCCESS=false
}

print_info() {
  echo -e "${CYAN}$1${NC}"
}

# Step 1: File Structure Validation
echo -e "\n${YELLOW}📁 Step 1: File Structure Validation${NC}"

print_info "Checking PowerShell files..."
PS_FILES=$(find . -name "*.ps1" -o -name "*.psm1" -o -name "*.psd1" | grep -v ".git" | wc -l)
echo "  Found $PS_FILES PowerShell files"

if [ $PS_FILES -gt 0 ]; then
  print_success "PowerShell files present"
  echo "  PowerShell files found:"
  find . -name "*.ps1" -o -name "*.psm1" -o -name "*.psd1" | grep -v ".git" | head -5 | sed 's/^/    /'
  if [ $PS_FILES -gt 5 ]; then
    echo "    ... and $((PS_FILES - 5)) more files"
  fi
else
  print_error "No PowerShell files found"
fi

# Step 2: Documentation Validation
echo -e "\n${YELLOW}📚 Step 2: Documentation Validation${NC}"

REQUIRED_DOCS=("README.md" "CHANGELOG.md" "LICENSE" "CONTRIBUTING.md")
MISSING_DOCS=()

print_info "Checking required documentation files..."
for doc in "${REQUIRED_DOCS[@]}"; do
  if [ -f "$doc" ]; then
    print_success "Found: $doc"
  else
    print_error "Missing: $doc"
    MISSING_DOCS+=("$doc")
  fi
done

# Check GitHub community files
GITHUB_DOCS=(".github/CODE_OF_CONDUCT.md" ".github/SECURITY.md" ".github/SUPPORT.md")
print_info "Checking community documentation files..."
for doc in "${GITHUB_DOCS[@]}"; do
  if [ -f "$doc" ]; then
    print_success "Found: $doc"
  else
    print_warning "Missing: $doc"
  fi
done

# Step 3: GitHub Templates Validation
echo -e "\n${YELLOW}🎯 Step 3: GitHub Templates Validation${NC}"

TEMPLATE_PATHS=(
  ".github/ISSUE_TEMPLATE/bug_report.yml"
  ".github/ISSUE_TEMPLATE/feature_request.yml"
  ".github/ISSUE_TEMPLATE/question.yml"
  ".github/ISSUE_TEMPLATE/config.yml"
  ".github/pull_request_template.md"
  ".github/workflows/ci.yml"
  ".github/workflows/release.yml"
  ".github/workflows/docs.yml"
)

MISSING_TEMPLATES=()
print_info "Checking GitHub templates..."
for template in "${TEMPLATE_PATHS[@]}"; do
  if [ -f "$template" ]; then
    print_success "Found: $template"
  else
    print_error "Missing: $template"
    MISSING_TEMPLATES+=("$template")
  fi
done

# Step 4: Workflow Syntax Validation
echo -e "\n${YELLOW}⚙️  Step 4: Workflow Syntax Validation${NC}"

print_info "Checking YAML workflow files..."
WORKFLOW_FILES=(".github/workflows/ci.yml" ".github/workflows/release.yml" ".github/workflows/docs.yml")

for workflow in "${WORKFLOW_FILES[@]}"; do
  if [ -f "$workflow" ]; then
    # Basic YAML syntax check (if python/yq available)
    if command -v python3 &>/dev/null; then
      if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
        print_success "YAML syntax valid: $(basename "$workflow")"
      else
        print_error "YAML syntax invalid: $(basename "$workflow")"
      fi
    else
      print_warning "Cannot validate YAML syntax (python3 not available): $(basename "$workflow")"
    fi
  fi
done

# Step 5: File Content Validation
echo -e "\n${YELLOW}🔍 Step 5: File Content Validation${NC}"

print_info "Checking README.md content..."
if [ -f "README.md" ]; then
  if grep -q "Windows Server" README.md; then
    print_success "README contains project context"
  else
    print_warning "README may be missing project context"
  fi

  if grep -q "Contributing" README.md; then
    print_success "README contains contributing section"
  else
    print_warning "README missing contributing section"
  fi
else
  print_error "README.md not found"
fi

print_info "Checking CHANGELOG.md content..."
if [ -f "CHANGELOG.md" ]; then
  if grep -q "Unreleased\|1\." CHANGELOG.md; then
    print_success "CHANGELOG has version entries"
  else
    print_warning "CHANGELOG may be missing version entries"
  fi
else
  print_error "CHANGELOG.md not found"
fi

# Step 6: Project Structure Analysis
echo -e "\n${YELLOW}🏗️  Step 6: Project Structure Analysis${NC}"

print_info "Analyzing project structure..."

# Check for main directories
EXPECTED_DIRS=("Scripts" "LabSetupTutorials" ".github" "Demo")
for dir in "${EXPECTED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    file_count=$(find "$dir" -type f | wc -l)
    print_success "Directory: $dir ($file_count files)"
  else
    print_warning "Missing directory: $dir"
  fi
done

# Check for demo organization
if [ -d "Demo" ]; then
  demo_files=$(find Demo -name "*.md" -o -name "*.ps1" | wc -l)
  if [ $demo_files -gt 0 ]; then
    print_success "Demo directory is organized ($demo_files files)"
  else
    print_warning "Demo directory exists but appears empty"
  fi
fi

# Step 7: Git Repository Status
echo -e "\n${YELLOW}📦 Step 7: Git Repository Status${NC}"

if [ -d ".git" ]; then
  print_success "Git repository initialized"

  # Check for .gitignore
  if [ -f ".gitignore" ]; then
    print_success ".gitignore file present"

    # Check if .gitignore has PowerShell-specific entries
    if grep -q "*.ps1\|*.psd1\|*.psm1" .gitignore 2>/dev/null; then
      print_warning ".gitignore may be blocking PowerShell files"
    else
      print_success ".gitignore allows PowerShell files"
    fi
  else
    print_warning ".gitignore file missing"
  fi

  # Check git status
  if git status &>/dev/null; then
    untracked=$(git status --porcelain | grep "^??" | wc -l)
    modified=$(git status --porcelain | grep "^.M\|^M" | wc -l)

    if [ $untracked -gt 0 ] || [ $modified -gt 0 ]; then
      print_info "Git status: $untracked untracked, $modified modified files"
    else
      print_success "Git working directory clean"
    fi
  fi
else
  print_error "Not a git repository"
fi

# Final Summary
echo -e "\n" "$(printf '=%.0s' {1..50})"
echo -e "${CYAN}🎯 Final CI/CD Validation Summary${NC}"
echo "$(printf '=%.0s' {1..50})"

if [ "$OVERALL_SUCCESS" = true ]; then
  print_success "ALL CHECKS PASSED! 🎉"
  echo -e "${GREEN}   Your project structure is ready for CI/CD${NC}"
  echo -e "${GREEN}   GitHub Actions workflows should run successfully${NC}"

  # Additional recommendations
  echo -e "\n${CYAN}💡 Recommendations:${NC}"
  if ! command -v pwsh &>/dev/null && ! command -v powershell &>/dev/null; then
    echo "  • Install PowerShell Core for full local testing"
  fi
  echo "  • Test workflows on GitHub after pushing"
  echo "  • Monitor workflow runs for any platform-specific issues"

  exit 0
else
  print_error "SOME CHECKS FAILED! 💥"
  echo -e "${RED}   Please fix the issues above before pushing to GitHub${NC}"
  echo -e "${RED}   Some GitHub Actions workflows may fail${NC}"

  if [ ${#MISSING_DOCS[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Missing documentation files:${NC}"
    printf '  • %s\n' "${MISSING_DOCS[@]}"
  fi

  if [ ${#MISSING_TEMPLATES[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Missing template files:${NC}"
    printf '  • %s\n' "${MISSING_TEMPLATES[@]}"
  fi

  exit 1
fi
