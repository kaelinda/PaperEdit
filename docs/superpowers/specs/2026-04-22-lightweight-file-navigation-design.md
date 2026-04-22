# PaperEdit Lightweight File Navigation Design

Date: 2026-04-22
Status: Draft approved in chat, written for review

## Summary

PaperEdit should position itself as a lightweight developer tool for quickly opening and editing configuration and structured text files, not as a small IDE. The primary job is to help the user enter the target file quickly, make a change confidently, and leave without managing a heavy workspace.

This design keeps the directory tree as the primary visual structure, but changes its role. The tree remains the main browsing surface, while Quick Open becomes the direct path when the user already knows the filename, and Favorites plus Recent provide fast return paths for high-frequency files.

## Product Intent

### Core scenario

PaperEdit is primarily for developers making quick edits to configuration and structured text files.

### Product priorities

1. More natural high-frequency workflows
2. More restrained interface behavior

### Primary pain point to solve

The current product makes directory browsing do too much. Finding a target file should not depend entirely on expanding folders in the sidebar.

## Goals

- Preserve the directory tree as the dominant visual anchor
- Make file entry faster for known filenames and high-frequency files
- Add a simple, explicit Favorites model based on manual pinning
- Reduce project-management language and interaction weight
- Keep the product feeling calm and compact during repeated use

## Non-goals

- Turning Quick Open into a full command center
- Adding automatic ranking, recommendation, or behavioral prediction
- Introducing new workspace panels, project dashboards, or IDE-style surfaces
- Expanding into terminal, git, diagnostics, or global search-and-replace workflows
- Building a complex Favorites manager with folders, grouping, or drag-heavy organization

## Current Product Constraints

Based on the current codebase:

- The app state is centered in `WorkspaceStore`
- The sidebar currently has three sections: `Pinned`, `Recent`, and `Explorer`
- The title bar already includes command entry points and tab switching
- The workspace tree is already the main file-browsing route

The design should therefore reshape the existing navigation model instead of replacing the shell.

## Proposed Information Architecture

The sidebar remains the primary navigation surface, but its internal hierarchy changes.

### Sidebar top area

The current search field becomes the main Quick Open entry point. It should remain visually embedded in the sidebar instead of becoming a permanent full-window overlay. Triggering Quick Open should open a lightweight floating result surface focused on file opening only.

### Favorites

The first content section becomes `Favorites`.

- It contains only manually pinned files
- It is intentionally small and stable
- It acts as the fastest return path for files the user repeatedly touches
- It should not infer ranking or auto-promote items

### Recent

The second section remains `Recent`.

- It represents recently opened files only
- Ordering is based on recency, not frequency
- It helps the user return to files from the current or recent editing loop

### Explorer

The main tree remains `Explorer`.

- It stays the largest visual section
- Its role is browsing and location confirmation
- It is no longer the only efficient path to a file

## Interaction Model

### Quick Open

Quick Open serves users who already know the file they want.

- It should search the current workspace files first
- It should include recent files as a secondary result source
- It should open or focus the existing tab instead of creating duplicate tabs
- It should remain narrow in scope: find file, open file, move on

Quick Open must not become an all-purpose action launcher in this iteration.

### Favorites behavior

Favorites use explicit user intent only.

- A file can be pinned or unpinned manually
- Pinning should be available through a lightweight action on file rows
- The action should stay visually quiet, such as a hover affordance or contextual action
- Favorites should persist independently from Recent

### Explorer behavior

Explorer remains the default visual context, but it should feel lighter.

- The user should still be able to browse folder structure normally
- The tree should be treated as the place for discovery and orientation
- Interface copy and decoration should avoid implying heavyweight project management

### Entry flow

The intended navigation mental model is:

- Use Explorer when the file location is only roughly known
- Use Quick Open when the filename is known
- Use Favorites to jump to stable high-frequency files
- Use Recent to jump back into the latest editing loop

## UX Guardrails

To preserve the small-and-beautiful positioning, the design must actively avoid the following:

- No expansion into multi-panel workspace management
- No new project abstractions beyond the current folder-based model
- No aggressive badges, counters, or dense control clusters
- No feature surfaces that make the app feel like a reduced IDE

Visual restraint matters, but restraint is subordinate to speed and clarity. Any chrome that does not help file entry should remain weak.

## Data and State Expectations

The navigation model needs a few clear state rules.

### Favorites persistence

- Favorites are stored separately from Recent
- They should remain stable across sessions
- If a favorite points to a file outside the currently visible workspace tree, it may still appear as a valid shortcut

### Recent persistence

- Recent continues to reflect recency only
- It should remain capped to a small, practical list

### Opening behavior

- Favorites, Recent, Explorer, and Quick Open must all reuse the same open-file path
- Reopening an already open file should focus the existing tab rather than duplicate it

## Content and Naming Direction

Language should move away from heavier product framing.

- Prefer concrete file-oriented labels over project-management wording
- The sidebar should feel like a lightweight file navigator, not a workspace console
- Labels and empty states should reinforce file access, not environment management

## Validation Criteria

The design is successful if the implemented product satisfies these checks:

1. After opening a folder, a user can get into a high-frequency configuration file in two steps or fewer.
2. When the user knows the filename, they do not need to traverse folder depth manually.
3. The interface still feels compact and restrained during repeated daily use.
4. Favorites, Recent, and Explorer have distinct jobs, so the user is not forced to guess where a file should appear.
5. The app still reads as a lightweight file editor rather than an IDE-like workspace tool.

## Implementation Notes For Planning

The eventual implementation plan should stay tightly scoped around navigation and product framing. It should favor:

- Sidebar information architecture changes
- Lightweight pin and unpin actions
- Quick Open behavior scoped to file access
- Copy and empty-state cleanup that reduces workspace heaviness
- Targeted state tests for Favorites, Recent, and duplicate-open prevention

It should avoid unrelated editor refactors or capability expansion.
