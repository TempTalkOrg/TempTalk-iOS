#!/usr/bin/env python3
"""
Parse Firebase Crashlytics results from JSON file.

Usage:
    cat <result_file> | python3 parse-crashlytics.py [--format table|json|summary]
    python3 parse-crashlytics.py <result_file> [--format table|json|summary]

Output formats:
    table   - Markdown tables (default)
    json    - JSON array of parsed issues
    summary - Brief summary statistics
"""

import json
import sys
import argparse


def parse_crashlytics_yaml(text: str) -> list[dict]:
    """Parse the YAML-like text from Crashlytics response into structured issues."""
    groups = text.split('groups: |')[1] if 'groups: |' in text else ''

    issues = []
    current_issue = {}

    for line in groups.split('\n'):
        line = line.strip()
        if line.startswith("eventsCount: '"):
            current_issue['events'] = int(line.split("'")[1])
        elif line.startswith("impactedUsersCount: '"):
            current_issue['users'] = int(line.split("'")[1])
        elif line.startswith('id: '):
            current_issue['id'] = line.split('id: ')[1]
        elif line.startswith('title: '):
            current_issue['title'] = line.split('title: ')[1]
        elif line.startswith('subtitle: '):
            current_issue['subtitle'] = line.split('subtitle: ')[1]
        elif line.startswith('firstSeenVersion: '):
            current_issue['first'] = line.split('firstSeenVersion: ')[1]
        elif line.startswith('lastSeenVersion: '):
            current_issue['last'] = line.split('lastSeenVersion: ')[1]
        elif line.startswith('state: '):
            current_issue['state'] = line.split('state: ')[1]
        elif line.startswith('- signal: '):
            current_issue['signal'] = line.split('- signal: ')[1]
        elif line.startswith('description: '):
            current_issue['signal_desc'] = line.strip("'").split('description: ')[1].strip("'")
        elif '- metrics:' in line and current_issue.get('id'):
            issues.append(current_issue)
            current_issue = {}

    if current_issue.get('id'):
        issues.append(current_issue)

    return issues


def format_status(issue: dict) -> str:
    """Format status with indicators."""
    state = issue.get('state', 'UNKNOWN')
    signal = issue.get('signal', '')

    status = 'OPEN' if state == 'OPEN' else 'CLOSED'
    if 'REGRESSED' in signal:
        status += ' REGRESSED'
    if 'FRESH' in signal:
        status += ' FRESH'
    return status


def output_table(issues: list[dict]) -> None:
    """Output issues as markdown tables."""
    total_crashes = sum(i.get('events', 0) for i in issues)
    total_users = sum(i.get('users', 0) for i in issues)

    print(f'**Total Issues Found**: {len(issues)}')
    print(f'**Total FATAL Crashes**: {total_crashes}')
    print(f'**Total Impacted Users**: {total_users}')
    print()

    # Top 15 by crash count
    print('### Top 15 by Crash Count')
    print('| # | Issue | Crashes | Users | Versions | Status |')
    print('|---|-------|---------|-------|----------|--------|')
    for i, issue in enumerate(issues[:15], 1):
        title = issue.get('title', 'Unknown')[:50]
        events = issue.get('events', 0)
        users = issue.get('users', 0)
        first = issue.get('first', '?')
        last = issue.get('last', '?')
        status = format_status(issue)
        print(f'| {i} | {title} | {events} | {users} | {first}->{last} | {status} |')

    # Fresh issues
    print()
    print('### New/Fresh Issues (SIGNAL_FRESH)')
    fresh = [i for i in issues if i.get('signal') == 'SIGNAL_FRESH']
    if fresh:
        print('| # | Issue | Crashes | Users | First Seen | Status |')
        print('|---|-------|---------|-------|------------|--------|')
        for i, issue in enumerate(fresh, 1):
            title = issue.get('title', 'Unknown')[:50]
            events = issue.get('events', 0)
            users = issue.get('users', 0)
            first = issue.get('first', '?')
            print(f'| {i} | {title} | {events} | {users} | {first} | FRESH |')
    else:
        print('No fresh issues found.')

    # Regressed issues
    print()
    print('### Regressed Issues (SIGNAL_REGRESSED)')
    regressed = [i for i in issues if i.get('signal') == 'SIGNAL_REGRESSED']
    if regressed:
        print('| # | Issue | Crashes | Users | Regressed Info | Status |')
        print('|---|-------|---------|-------|----------------|--------|')
        for i, issue in enumerate(regressed, 1):
            title = issue.get('title', 'Unknown')[:50]
            events = issue.get('events', 0)
            users = issue.get('users', 0)
            desc = issue.get('signal_desc', '')[:60]
            print(f'| {i} | {title} | {events} | {users} | {desc}... | REGRESSED |')
    else:
        print('No regressed issues found.')


def output_summary(issues: list[dict]) -> None:
    """Output brief summary statistics."""
    total_crashes = sum(i.get('events', 0) for i in issues)
    total_users = sum(i.get('users', 0) for i in issues)
    fresh = len([i for i in issues if i.get('signal') == 'SIGNAL_FRESH'])
    regressed = len([i for i in issues if i.get('signal') == 'SIGNAL_REGRESSED'])

    print(f'Issues: {len(issues)}')
    print(f'Crashes: {total_crashes}')
    print(f'Users: {total_users}')
    print(f'Fresh: {fresh}')
    print(f'Regressed: {regressed}')


def main():
    parser = argparse.ArgumentParser(description='Parse Firebase Crashlytics results')
    parser.add_argument('file', nargs='?', help='Input file (or use stdin)')
    parser.add_argument('--format', choices=['table', 'json', 'summary'], default='table',
                        help='Output format (default: table)')
    args = parser.parse_args()

    # Read input
    if args.file:
        with open(args.file, 'r') as f:
            content = f.read()
    else:
        content = sys.stdin.read()

    # Parse JSON wrapper
    data = json.loads(content)
    text = data[0]['text']

    # Parse YAML-like content
    issues = parse_crashlytics_yaml(text)

    # Output in requested format
    if args.format == 'json':
        print(json.dumps(issues, indent=2))
    elif args.format == 'summary':
        output_summary(issues)
    else:
        output_table(issues)


if __name__ == '__main__':
    main()
