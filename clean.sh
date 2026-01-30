#!/bin/bash

set -e

# Configuration
GITHUB_ORG="htc-demo-00-gcp"
ORCHESTRATOR_ORG="htc-demo-00-gcp"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to clean orchestrator environments
clean_orchestrator_envs() {
    local project_name=$1

    print_info "Checking orchestrator environments for project: $project_name in org: $ORCHESTRATOR_ORG"

    # Check if hctl command exists
    if ! command_exists hctl; then
        print_error "hctl command not found. Please ensure it is installed and in your PATH."
        return 1
    fi

    # List environments for the project
    print_info "Listing environments..."
    if hctl get environments "$project_name" --org "$ORCHESTRATOR_ORG" >/dev/null 2>&1; then
        local envs=$(hctl get environments "$project_name" --org "$ORCHESTRATOR_ORG" 2>/dev/null | grep -v "^Id" | awk '{print $1}' || true)

        if [ -z "$envs" ]; then
            print_warning "No environments found for project: $project_name"
        else
            print_info "Found environments for $project_name:"
            echo "$envs"

            # Delete each environment
            while IFS= read -r env; do
                if [ -n "$env" ]; then
                    print_info "Deleting environment: $env"
                    if hctl delete environment "$project_name" "$env" --org "$ORCHESTRATOR_ORG" --force --no-prompt 2>/dev/null; then
                        print_info "Successfully deleted environment: $env"
                    else
                        print_warning "Failed to delete environment: $env (it may not exist or you may not have permissions)"
                    fi
                fi
            done <<< "$envs"
        fi

        # Delete the project after all environments are deleted
        print_info "Deleting project: $project_name"
        if hctl delete project "$project_name" --org "$ORCHESTRATOR_ORG" --delete-rules 2>/dev/null; then
            print_info "Successfully deleted project: $project_name"
        else
            print_warning "Failed to delete project: $project_name (it may not exist or you may not have permissions)"
        fi
    else
        print_warning "Could not list environments for project: $project_name (project may not exist)"
    fi

    return 0
}

# Function to clean GitHub repo
clean_github_repo() {
    local project_name=$1
    local repo_full_name="${GITHUB_ORG}/${project_name}"

    print_info "Cleaning GitHub repository: $repo_full_name"

    # Check if gh command exists
    if ! command_exists gh; then
        print_error "gh (GitHub CLI) command not found. Please ensure it is installed and in your PATH."
        return 1
    fi

    # Check if repo exists
    print_info "Checking if repository exists..."
    if gh repo view "$repo_full_name" >/dev/null 2>&1; then
        print_info "Repository found: $repo_full_name"
        print_info "Deleting GitHub repository: $repo_full_name"
        if gh repo delete "$repo_full_name" --yes 2>/dev/null; then
            print_info "Successfully deleted GitHub repository: $repo_full_name"
        else
            print_error "Failed to delete GitHub repository: $repo_full_name"
            return 1
        fi
    else
        print_warning "GitHub repository not found: $repo_full_name"
    fi

    return 0
}

# Main script
main() {
    # Check if project name is provided
    if [ -z "$1" ]; then
        print_error "Usage: $0 <project-name>"
        print_error "Example: $0 my-project"
        exit 1
    fi

    local project_name=$1

    print_info "Starting cleanup process for project: $project_name"
    echo "========================================"

    # Step 1: Clean orchestrator environments
    print_info "Step 1: Cleaning orchestrator environments"
    if clean_orchestrator_envs "$project_name"; then
        print_info "Orchestrator environments cleanup completed"
    else
        print_error "Orchestrator environments cleanup failed"
        exit 1
    fi

    echo ""

    # Step 2: Clean GitHub repo
    print_info "Step 2: Cleaning GitHub repository"
    if clean_github_repo "$project_name"; then
        print_info "GitHub repository cleanup completed"
    else
        print_warning "GitHub repository cleanup completed with warnings"
    fi

    echo ""
    print_info "========================================"
    print_info "Cleanup process completed successfully for project: $project_name"
}

# Run main function
main "$@"
