# Contexts Master Plan

## Source Anchors
This plan uses current platform references from Apple and competitor docs: [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem), [SwiftUI MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra), [WidgetKit](https://developer.apple.com/documentation/WidgetKit/), [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts), [Quartz Window Services](https://developer.apple.com/documentation/coregraphics/quartz-window-services), [macOS Focus settings](https://support.apple.com/guide/mac-help/change-focus-settings-mchlff5da36d/mac), [Stage Manager](https://support.apple.com/en-us/HT213315), [Raycast](https://www.raycast.com/), and [Keyboard Maestro](https://www.stairways.com/).

---

## 1. Executive Product Vision

### One-Sentence Thesis
Contexts is the one-click “mode switch” for your Mac: it restores the apps, windows, files, URLs, focus settings, and calm working environment you need for the task at hand.

### Why This App Should Exist Now
Modern Mac work has become fragmented across apps, browser tabs, communication tools, file systems, calendars, and external displays. The cost is not just time; it is cognitive residue. People constantly reassemble their environment before they can begin meaningful work.

macOS has strong primitives: Mission Control, Spaces, Stage Manager, Focus, Shortcuts, widgets, App Intents, and excellent native UI frameworks. But those primitives remain scattered. Contexts packages them into a coherent ritual: “I am entering Writing,” “I am entering Coding,” “I am entering Meetings.”

### Why macOS Is the Right Platform
macOS is where knowledge workers do dense, multi-window, multi-app work. It has:
- Rich windowing and multiple display workflows.
- Mature automation culture.
- Users who pay for polished utilities.
- Menu bar utility expectations.
- Native frameworks for Shortcuts, widgets, Apple Events, AppKit, SwiftUI, and Accessibility.
- A long-standing culture of apps like Bartender, CleanShot X, Alfred, Raycast, Magnet, BetterTouchTool, and Keyboard Maestro.

### What It Solves Better Than Existing Tools
| Tool | Strength | Why It Falls Short | Contexts Advantage |
|---|---:|---|---|
| Stage Manager | Keeps active apps visually grouped | Not project-aware; no files, URLs, Focus, cleanup, templates, or automation state | Saves named work modes, not just stages |
| Mission Control / Spaces | Native spatial organization | Manual, fragile, no saved preset model | Restores repeatable working setups |
| Raycast | Fast launcher and command hub | Great at actions, less focused on persistent workspace state | Contexts owns the “enter this mode” ritual |
| BetterTouchTool | Deep power-user automation | Powerful but technical and configuration-heavy | Safer, opinionated, polished presets |
| Keyboard Maestro | Extremely capable automation | Too abstract for normal users; macro mindset | Human-centered “contexts,” not macros |
| Shortcuts | Native automation graph | Not designed as a live workspace manager | Contexts provides durable UI, state, health checks, and context lifecycle |
| Window managers | Move/resize windows well | Only solve geometry | Contexts combines geometry with intent, apps, files, URLs, focus, and cleanup |

### Unique Wedge
“Save and restore complete work modes from the menu bar.”  
This is more emotionally resonant than “window layouts” and less intimidating than “automation.”

### Long-Term Moat
- User-specific setup investment: saved contexts become personal infrastructure.
- Reliability engine: app-specific restoration heuristics improve over time.
- Template ecosystem: best-practice context recipes for developers, writers, students, editors, founders.
- Trust layer: permissions health, rollback, explainable automation, local-first storage.
- Native integration depth: App Intents, widgets, Shortcuts, menu bar, calendar suggestions, and system-aware recovery.

---

## 2. Target Users And JTBD

### Personas

| Persona | Daily Workflow | Pain Points | Setup Rituals | Current Workarounds | Willingness To Pay | Aha Moment |
|---|---|---|---|---|---:|---|
| Developer | Switches between IDE, terminal, browser docs, Linear/Jira, Slack, local servers | Losing terminal/browser/project state; distraction from Slack; external monitor changes | Open Xcode/VS Code, repo folder, terminal tabs, docs, issue tracker | Raycast, tmux, Spaces, manual window manager | High: $49-$99/year or $79 lifetime | “Coding” opens repo, docs, terminal, browser, issue, hides Slack, starts Focus |
| Freelance Designer / Editor | Client work across Figma, Adobe apps, Finder assets, browser references, invoices | Client/project context scattered; heavy files; multiple monitors | Open Figma file, asset folder, reference links, export folder | Finder favorites, Stage Manager, app recents | High if saves billable time | “Client: Acme” restores the exact workbench |
| Student / Researcher | Research, writing, lectures, notes, PDFs, Zotero, browser tabs | Browser tab chaos; switching from class to writing to deep reading | Open lecture notes, readings, paper outline, citation manager | Browser bookmarks, Notion, tabs | Medium: student discount needed | “Research” opens PDFs, Zotero, notes, and silences socials |
| Startup Founder / Operator | Meetings, email, planning, investor docs, metrics, hiring | Reactive switching; calendar-driven chaos | Open calendar, Zoom, CRM, docs, Slack channels | Calendar, Raycast, manual browser profiles | High if framed as executive control | Meeting context appears 5 minutes before call |
| Creator / Video Editor | Editing, scripting, publishing, analytics, assets, reference media | App-heavy workflow; storage paths; distractions; render monitoring | Open Final Cut/Premiere, assets, music folder, YouTube Studio | Dock, Finder tags, window manager | High: creator tools are expensive | “Editing” puts timeline full screen, assets on side monitor, hides chat |
| Writer / Consultant | Drafting, research, email, client docs, calls | Writing interrupted by admin and meetings | Open writing app, research tabs, notes, timer | Focus apps, full-screen writing, bookmarks | Medium-high | “Deep Writing” creates calm in one click |

### Jobs To Be Done

#### Functional Jobs
- Restore a known workspace quickly.
- Launch the right apps, files, folders, and URLs together.
- Move windows into usable positions.
- Hide or quit distracting apps.
- Start a focus session or timer.
- Prepare for meetings automatically or semi-automatically.
- Clean up after a work mode.
- Share or import reusable context templates.

#### Emotional Jobs
- Feel ready instead of scattered.
- Reduce the “where was I?” tax.
- Feel that the Mac is cooperating.
- Trust that switching modes will not create chaos.
- End the day with fewer loose ends.

#### Identity / Social Jobs
- “I am organized.”
- “I have a professional setup.”
- “My workflow feels intentional.”
- “I use my Mac like a serious craftsperson.”

---

## 3. Competitor Analysis

### Native macOS Features
- Mission Control and Spaces are spatial, not semantic. They help arrange work but do not understand “Writing,” “Meetings,” or “Admin.”
- Stage Manager groups windows but does not save reusable named contexts, launch supporting materials, or manage lifecycle.
- Focus is powerful but notification-centric. It does not prepare apps, windows, documents, or URLs.
- Shortcuts is powerful but abstract. Users must build logic themselves.

### Window Managers
Examples: Rectangle, Magnet, Moom, BetterSnapTool.
- Excellent at window geometry.
- Weak at project setup, app launch sets, files, URLs, Focus, cleanup, and state memory.
- Usually operate at the “move this window” level, not the “enter this work mode” level.

### Launchers
Examples: Raycast, Alfred, LaunchBar.
- Great keyboard-first command execution.
- Weak as persistent workspace state managers.
- They can launch apps and run scripts, but the conceptual center is command invocation, not context lifecycle.

### Automation Tools
Examples: Keyboard Maestro, BetterTouchTool, Shortcuts.
- Deeply capable but too technical for broad premium adoption.
- Users must think in triggers, actions, variables, permissions, scripts, and failure handling.
- Contexts should expose safe recipes, visible state, previews, and rollback.

### Focus Apps
Examples: Opal, Freedom, Session, Focus.
- Strong at blocking or timers.
- Usually do not manage complete workspace setup.
- Contexts can include light focus behavior without becoming a punitive blocker app.

### Productivity Suites
Examples: Notion, Todoist, Akiflow, Motion.
- Manage tasks and information.
- Do not prepare the local Mac environment.
- Contexts should integrate with calendar/tasks later, but own the execution environment.

---

## 4. Product Positioning

### Category Definition
Workspace orchestration for Mac.

### Recommended Framing
Best: **“Modes for your Mac.”**

Why:
- Human, emotional, and understandable.
- Broader than “workspace switching.”
- Less technical than “automation.”
- Directly supports the feeling: “My Mac adapts to what I’m doing.”

Secondary line: **“One click into the right setup.”**

### One-Line Pitch
Contexts lets you save and switch complete Mac work modes: apps, windows, files, links, Focus, and cleanup in one click.

### App Store Subtitle
Modes for your Mac.

### Website Hero Headline
Your Mac, ready for what you’re doing.

### Supporting Hero Copy
Save your Coding, Writing, Meeting, Research, and Deep Work setups, then restore them from the menu bar in one click.

### Five Feature Bullets
- Save complete contexts with apps, files, folders, URLs, and window layouts.
- Switch modes instantly from the menu bar or keyboard.
- Hide distractions and start focused sessions.
- Recover gracefully when apps, displays, or permissions change.
- Build from native templates, then customize as deeply as you want.

### Ten Ad Angles
1. Stop rebuilding your workspace every morning.
2. One click from meetings to deep work.
3. Your Mac should remember how you work.
4. The missing preset button for macOS.
5. Save 10 minutes every workday.
6. Make project switching feel calm.
7. Built for people with too many windows.
8. A premium menu bar utility for serious Mac work.
9. Context switching without the cognitive tax.
10. Turn your Mac into work modes.

### Ten Launch Hooks
1. “I built the app Apple should have added to Stage Manager.”
2. “A preset button for your Mac workspace.”
3. “From Slack chaos to deep work in one click.”
4. “My entire coding setup now opens from the menu bar.”
5. “Why window managers stop one layer too early.”
6. “A calm alternative to giant automation tools.”
7. “Save your Mac setup like a document.”
8. “The fastest way to switch projects on macOS.”
9. “What if Focus mode also prepared your apps?”
10. “The Mac utility for people who live in modes.”

### Best Language
Use:
- Context
- Mode
- Setup
- Restore
- Prepare
- Switch
- Focus
- Clean up
- Workspace

Avoid:
- Macro
- Script
- Workflow engine
- Automation graph
- Hack
- Window manager replacement

---

## 5. Feature Stack

### Core MVP
| Feature | Problem Solved | Complexity | Dependencies | Risk | Retention | Monetization |
|---|---|---:|---|---|---:|---:|
| Save context presets | Gives product core object | Medium | Local storage, UI | Low | Very high | High |
| Launch app sets | Reduces setup ritual | Medium | NSWorkspace | App launch variance | High | High |
| Open URLs/files/folders | Restores materials | Low | NSWorkspace | Missing resources | High | High |
| Restore window layouts | Core magic | High | Accessibility, CGWindow info | Reliability | Very high | High |
| Menu bar quick switcher | Daily habit | Medium | NSStatusItem/MenuBarExtra | UI polish | Very high | High |
| Keyboard shortcuts | Pro adoption | Medium | Hotkey manager | Conflicts | High | Medium |
| Recently used contexts | Fast switching | Low | Usage history | Low | High | Medium |
| Permissions center | Trust and reliability | Medium | TCC checks | OS variance | High | High |
| Context templates | Activation | Low-medium | Template JSON | Wrong defaults | Medium | Medium |
| Partial failure recovery | Trust | Medium | Run logs | Complexity | High | High |

Cut for MVP:
- Calendar/location suggestions.
- Widgets.
- Shared template gallery.
- Sync.
- Browser tab restoration beyond opening URLs.
- Full Focus automation unless via user-configured Shortcuts.

### V1 Launch
Add:
- Context editor with apps, files, URLs, window layout, hide/quit actions.
- Run confirmation sheet for risky actions.
- Active session view with timer.
- Temporary contexts.
- Cleanup context.
- Import/export.
- App Intents for “Run Context,” “Stop Context,” “Create Temporary Context.”
- Basic Shortcuts support.
- Backup to local file / iCloud Drive folder.

### V1.5
Add:
- Calendar smart suggestions.
- Time-of-day suggestions.
- Template gallery.
- Display profile awareness.
- Browser profile support for Safari/Chrome/Arc where feasible.
- Session history and saved-time estimates.
- Desktop widget if usage data proves valuable.

### V2
Add:
- iCloud sync.
- Team/shared templates.
- iPhone companion as remote switcher.
- Advanced rules engine.
- App-specific restoration plugins.
- Community template marketplace.
- AI-assisted context suggestions from observed usage, strictly local-first unless opted in.

### Feature Detail Notes
- Focus/DND: do not promise direct Focus toggling via private APIs. Use guided Shortcuts setup, user-created Focus automations, and App Intents. If a helper can run a user-approved Shortcut, label it as “Run Shortcut: Start Deep Work Focus.”
- Spaces: support best effort only. Avoid claiming reliable Space assignment because public APIs are limited.
- Window restore: treat as “restore as closely as macOS allows,” with visible confidence and recovery.

---

## 6. Information Architecture

### Menu Bar App
- Current Context
- Pinned Contexts
- Recent Contexts
- Start Temporary Context
- Pause / Stop Session
- Fix Setup Issues
- Open Contexts
- Settings
- Help

### Main Window
Use a native three-column structure:
- Sidebar: Dashboard, Contexts, Templates, Automation, History, Setup Health.
- Content: selected section.
- Inspector: details for selected context or rule.

### Sidebar Sections
- Dashboard
- Context Library
- Templates
- Automation Rules
- Session History
- Setup Health
- Settings

### Settings Sections
- General
- Menu Bar
- Keyboard Shortcuts
- Permissions
- Window Restoration
- Focus & Shortcuts
- Backup & Import
- Privacy
- Advanced
- Billing

### Onboarding Flow
1. Welcome: “Give your Mac work modes.”
2. Pick templates.
3. Add first apps/files/URLs.
4. Grant Accessibility.
5. Capture current layout.
6. Test run.
7. Finish with menu bar education.

### Context Creation Wizard
Steps:
1. Name & intent.
2. Apps.
3. Files, folders, URLs.
4. Windows.
5. Focus & distractions.
6. Cleanup behavior.
7. Shortcut and pinning.
8. Test.

### Permissions Center
- Accessibility: required for window positioning.
- Automation / Apple Events: needed for supported app-specific actions.
- Files/Folders security-scoped bookmarks: needed for persistent file access.
- Notifications: optional for session alerts.
- Calendar: optional for meeting suggestions.
- Location: defer; likely not MVP.
- Screen Recording: avoid unless a future visual capture feature truly needs it.

---

## 7. Screen-By-Screen UX Spec

### Menu Bar Dropdown
Purpose: fastest daily switching surface.

Layout:
- Header: current context name, elapsed timer, status dot.
- Primary action row: `Switch Context`, `New Temporary`, `Stop`.
- Pinned contexts: 3-7 rows with icon, name, subtitle, hotkey.
- Recents: last 3 contexts.
- Setup health row if needed.
- Footer: Open Contexts, Settings.

Microcopy:
- “Coding is active.”
- “2 items need attention.”
- “Restore as much as possible.”

Keyboard:
- Arrow keys navigate.
- Return runs selected context.
- Option-click opens edit.
- Command-click runs without confirmation if safe.

Analytics:
- `menubar_opened`
- `context_run_from_menubar`
- `health_warning_clicked`

### Main Dashboard
Purpose: summary and confidence.

Layout:
- Top: active context card, elapsed time, stop/switch buttons.
- Middle: pinned contexts grid.
- Right inspector: setup health and suggestions.
- Bottom: recent sessions and saved-time estimate.

Empty State:
“Create your first context by saving the setup you already have open.”

### Context Library
Purpose: manage all contexts.

Layout:
- Sidebar-filterable list: All, Pinned, Recent, Templates, Archived.
- Table rows with icon, name, last run, health status, hotkey.
- Inspector shows included apps/files/actions.

Controls:
- New Context
- Duplicate
- Archive
- Export
- Test Run

### Create/Edit Context Wizard
Purpose: make setup easy without exposing automation complexity.

Key Controls:
- Add App
- Add File / Folder
- Add URL
- Capture Current Windows
- Hide Apps
- Quit Apps
- Add Shortcut Action
- Test Context

Microcopy:
- “Window positions are restored best-effort. Some apps may reopen differently.”
- “You can run this safely. Contexts will show what changed before closing apps.”

### Run Context Confirmation Sheet
Purpose: prevent surprising changes.

Show only when:
- Quitting apps.
- Closing windows.
- Moving many windows.
- Missing permissions.
- First run of a context.

Layout:
- “Run Coding?”
- Will open: VS Code, Terminal, Safari.
- Will move: 4 windows.
- Will hide: Slack, Messages.
- Issues: “Focus requires Shortcut setup.”
- Buttons: Run, Review, Cancel.

### Active Session View
Purpose: session confidence and control.

Elements:
- Context name.
- Timer.
- Running checklist.
- Stop / Pause.
- Cleanup action.
- Notes field optional, V1.5.

### Permissions Center
Purpose: trust.

States:
- Ready
- Recommended
- Missing
- Broken
- Needs recheck

Microcopy:
- “Accessibility lets Contexts move and resize windows. It does not read your typing.”
- “You can use Contexts without this, but window restore will be limited.”

### Automation Rules Editor
Purpose: suggestions and optional triggers.

V1.5 layout:
- Trigger: time, calendar event, app opened, manual only.
- Action: suggest context, do not auto-run by default.
- Safety: require confirmation toggle.

Default:
Suggestions, not automatic switching.

### Templates Gallery
Template names:
- Coding
- Deep Work
- Meetings
- Writing
- Research
- Admin
- Editing
- Teaching
- Client Work
- Shutdown

Each template includes suggested apps/actions but no hardcoded user data.

### Keyboard Shortcuts Panel
Layout:
- Global switcher hotkey.
- Individual context hotkeys.
- Conflict detection.
- Reset defaults.

Default:
- Global switcher: `Control Option Space`
- Quick run pinned 1-5: optional, unset by default.

### Upgrade Screen
Tone: premium and respectful.

Headline:
“Make Contexts part of your daily setup.”

Tiers:
- Trial
- Contexts Pro
- Contexts Lifetime

Avoid aggressive blockers during onboarding.

### Recovery / Troubleshooting Page
Sections:
- Window restore accuracy.
- Missing apps/files.
- Permission reset.
- Display changed.
- Browser tabs did not open.
- App-specific notes.

---

## 8. macOS UI / Visual Design System

### Core Feel
Native, calm, precise, understated. It should look like a serious Mac utility from a small premium studio, not a web dashboard.

### Structure
- SwiftUI for main content and settings.
- AppKit for menu bar, accessibility/window APIs, advanced panels.
- Native toolbar with title, search, plus button, and segmented controls.
- Sidebar with `NavigationSplitView`.
- Sheets for confirmations.
- Inspector for context details.

### Materials
Use translucency carefully:
- Menu bar popover: `NSVisualEffectView` with sidebar/popover material.
- Main window: mostly solid system backgrounds for readability.
- Avoid glassy decorative panels.

### Typography
- Large title: 28 pt, semibold.
- Section title: 17 pt, semibold.
- Row title: 13-14 pt, medium.
- Body: 13 pt.
- Secondary: 11-12 pt.
- Monospaced only for shortcuts and diagnostics.

### Iconography
Use SF Symbols:
- Coding: `chevron.left.forwardslash.chevron.right`
- Writing: `pencil.and.outline`
- Meetings: `video`
- Deep Work: `moon.zzz`
- Research: `books.vertical`
- Admin: `tray.full`
- Editing: `film`
- Health: `checkmark.shield`
- Warning: `exclamationmark.triangle`

### Color
Use semantic color, not brand-heavy color:
- Accent: system blue or user-selectable accent.
- Success: system green.
- Warning: system yellow/orange.
- Error: system red.
- Active context: accent-tinted status dot.
- Avoid large saturated panels.

### Lists vs Cards
- Use table/list rows for contexts.
- Use small cards only for pinned contexts and templates.
- No nested card layouts.

### States
- Hover: subtle material lift or row highlight.
- Selection: native accent selection.
- Active context: left accent bar plus status dot.
- Disabled: native reduced opacity plus reason tooltip.

### Animation
- 120-180 ms transitions.
- Window run progress checklist animates linearly.
- No playful bouncing.
- Respect Reduce Motion.

### Accessibility
- Full keyboard access.
- VoiceOver labels for context actions.
- High contrast support.
- Dynamic Type where reasonable on macOS.
- No color-only status indicators.

---

## 9. Menu Bar UX

### Bar Presence
Default: icon-only menu bar item.

Icon:
- Base: layered rectangles or SF Symbol-inspired workspace glyph.
- Active context: filled variant or small dot.
- Timer active: optional ring/progress state.
- Error: tiny warning badge, only if actionable.
- Permission issue: shield/exclamation state.

Optional text:
- Setting: “Show active context name in menu bar.”
- Example: `Coding · 42m`
- Off by default to preserve menu bar space.

### Dropdown Structure
1. Active context header.
2. Quick switcher search field.
3. Pinned contexts.
4. Recent contexts.
5. Session actions.
6. Setup health.
7. Footer.

### What Can Be Done Without Full App
- Run a context.
- Stop active context.
- Start temporary context from current setup.
- Open recent context.
- Fix top permission issue.
- Open a missing file picker.
- Start/stop timer.
- Search contexts.

### Panel vs Full Window
Popover:
- Quick switching.
- Session status.
- Simple health action.
- Temporary context naming.

Full window:
- Editing context.
- Permissions center.
- Templates gallery.
- Billing.
- Automation rules.

### Apple Best-Practice Alignment
- Glanceable.
- Minimal persistent menu bar footprint.
- Native interactions.
- No noisy status text by default.
- Avoid custom oversized popover unless user opens command palette.

---

## 10. Widgets, Shortcuts, App Intents, And Automation

### Desktop Widgets
Honest evaluation: useful later, not MVP-critical.

Potential widgets:
- Small: current context + stop button.
- Medium: pinned contexts.
- Large: day plan with suggested contexts.

WidgetKit model:
- Timeline updates for session elapsed state and suggestions.
- Deep links into app actions.
- Use App Intents for interactive widget buttons where supported.

### Shortcuts Support
Expose:
- Run Context
- Stop Context
- Create Temporary Context
- Get Current Context
- List Contexts
- Export Context

Purpose:
- Lets power users chain Contexts with Focus, HomeKit, calendar workflows, and scripts.

### App Intents
Entities:
- `ContextEntity`
- `ContextRunResult`
- `SessionEntity`

Actions:
- `RunContextIntent`
- `StopContextIntent`
- `StartTemporaryContextIntent`
- `OpenContextsDashboardIntent`

### Spotlight
Use App Shortcuts phrases:
- “Run Coding in Contexts”
- “Switch to Deep Work”
- “Stop current context”

### Suggested Automations
V1.5:
- “You often run Writing around 9 AM.”
- “Meeting starts in 5 minutes. Prepare Meeting context?”
- “External display connected. Restore Coding?”

Default behavior: suggest, not auto-run.

---

## 11. Onboarding And First-Run Experience

### Activation Funnel
1. Welcome:
   “Give your Mac work modes.”
2. Pick starting templates:
   Coding, Writing, Meetings, Deep Work, Research.
3. Create first context:
   “Use what’s open now” recommended.
4. Add apps/files/URLs.
5. Explain Accessibility:
   “Needed to restore window positions.”
6. Capture layout.
7. Test run.
8. Pin context to menu bar.
9. Finish:
   “Your first context is ready in the menu bar.”

### Permission Order
Ask only when needed:
1. Accessibility during window capture/restore.
2. File access when adding persistent files/folders.
3. Notifications when enabling timers.
4. Calendar when enabling meeting suggestions.
5. Automation/Apple Events only for app-specific actions.

### Denied Permission Fallback
If Accessibility denied:
- App launching still works.
- Files/URLs still open.
- Window restore disabled.
- UI says: “Window restore is off until Accessibility is enabled.”

### Setup Completion Checklist
- Add first context.
- Pin to menu bar.
- Grant Accessibility.
- Test run.
- Add keyboard shortcut.
- Add cleanup action.

### First Aha
The first successful run should visibly:
- Open at least two resources.
- Move at least one window if permitted.
- Hide one distraction optionally.
- Show “Coding is ready.”

---

## 12. Permissions, Trust, And Safety

### Required / Optional Permissions
| Permission | Required? | Used For | Messaging |
|---|---:|---|---|
| Accessibility | Required for full value | Move/resize windows, inspect app windows | “Restore window layouts” |
| Automation / Apple Events | Optional | App-specific actions, browser control where supported | “Control selected apps with your approval” |
| Files/Folders | Context-specific | Persistent docs/folders | “Open saved files reliably” |
| Notifications | Optional | Timers, run completion | “Session reminders” |
| Calendar | Optional V1.5 | Meeting suggestions | “Suggest context before meetings” |
| Screen Recording | Avoid MVP | Visual window thumbnails only if future feature needs it | Do not request unless necessary |

### Privacy
- Contexts stored locally by default.
- No file contents indexed for MVP.
- Analytics opt-in or privacy-preserving by default.
- Sync optional and explainable.
- Export format human-readable JSON bundle.

### Safety
- Dry-run preview before destructive actions.
- No auto-quit by default.
- “Ask before quitting apps” enabled.
- “Undo last run” attempts to restore previous window positions and reopen hidden apps.
- Run log shows every action and outcome.

### Broken Permission Recovery
- Detect TCC revocation.
- Show exact System Settings path.
- Provide “Recheck Permission.”
- Explain what still works without permission.
- Maintain diagnostic bundle for support.

### Crash / Failure Handling
- Run context transactionally where possible.
- Record action states before mutation.
- Partial failure banner:
  “Coding mostly restored. 2 windows need attention.”
- Never repeatedly retry noisy actions.

---

## 13. Monetization And Packaging

### Recommendation
Hybrid: free trial + paid Pro with annual subscription and lifetime option.

Mac utility buyers often prefer ownership, but ongoing macOS compatibility work is real. The best model is:
- 14-day full-feature trial.
- `Contexts Pro`: $39/year launch, later $49/year.
- `Contexts Lifetime`: $89 launch, later $129.
- Student: $19/year.
- Family/team: delay.

### Why Not Subscription Only
Mac utility users are skeptical of subscriptions for utilities. A lifetime option increases trust and launch conversion.

### Why Not One-Time Only
Window automation requires ongoing maintenance across macOS updates, app behavior changes, and permission shifts.

### Free Tier
Avoid a permanent free tier if support burden is high. Use trial instead.

### Paywalled Features
Trial includes all.

After trial:
- Free viewer mode: run 1 context, no automation.
- Pro: unlimited contexts, window layouts, shortcuts, templates, import/export, history.
- V1.5 Pro: suggestions, calendar, widgets.
- Lifetime: same feature set as Pro.

### Upgrade Prompts
Trigger after:
- Trial day 7.
- Third successful context run.
- Attempt to create third context after trial.
- Export/import after trial.

Tone:
“Contexts is ready to become part of your daily Mac setup.”

---

## 14. Retention And Stickiness

### Habit Loops
- User opens Mac.
- Contexts suggests or shows pinned mode.
- User runs context.
- Workspace feels ready.
- End session cleanup reinforces control.

### Lock-In Through Setup Value
The more contexts a user creates, the more valuable the app becomes:
- Project-specific contexts.
- Client contexts.
- Personal routines.
- Display profiles.
- Keyboard shortcuts.

### Saved-Time Metrics
Show quietly:
- “You ran Coding 18 times this month.”
- “Estimated setup time saved: 2h 24m.”
Avoid gamified streaks; they feel wrong for a calm utility.

### Session History
Useful, but keep restrained:
- Context run count.
- Last run.
- Average session length.
- Failures needing attention.

### Why People Do Not Churn
- Lives in menu bar.
- Saves daily setup time.
- Becomes muscle memory.
- Handles multiple projects.
- Native trust and reliability.
- Import/export reduces fear of lock-in.

---

## 15. Metrics

### North Star
Weekly successful context runs per activated user.

### Activation Metrics
- Onboarding started.
- First context created.
- Accessibility granted.
- First context run.
- First successful run with 2+ actions.
- First context pinned.
- User returns next day.

### Usage Metrics
- Context runs per week.
- Menu bar opens per week.
- Keyboard shortcut runs.
- Active session starts.
- Cleanup actions used.
- Temporary contexts created.

### Reliability Metrics
- Full success rate.
- Partial success rate.
- Window restore failure rate.
- Missing file rate.
- Permission failure rate.
- App launch timeout rate.

### Conversion Metrics
- Trial start.
- Trial day 1/7/14 active.
- Upgrade screen views.
- Purchase conversion.
- Lifetime vs annual split.

### Churn Indicators
- No context run in 14 days.
- Repeated restore failures.
- Accessibility revoked.
- Trial user creates only one context.
- User opens troubleshooting repeatedly.

### Support Metrics
- Permission support tickets.
- App-specific restore complaints.
- Refund reasons.
- Crash-free sessions.

---

## 16. Technical Implementation Plan

### Architecture
Native hybrid:
- SwiftUI: main window, settings, onboarding, templates, dashboard.
- AppKit: menu bar, popovers, window APIs, Accessibility, event monitoring.
- App Intents: Shortcuts, Spotlight, widgets.
- WidgetKit: V1.5+.

### Modules
- `ContextsApp`: lifecycle and app delegate bridge.
- `MenuBar`: status item, popover, quick switcher.
- `ContextCore`: models, run engine, action graph.
- `WindowEngine`: capture/restore via Accessibility and CGWindow metadata.
- `ResourceOpener`: apps, files, folders, URLs.
- `Permissions`: TCC status, education, health checks.
- `Sessions`: active context, timers, history.
- `Templates`: bundled template definitions.
- `ShortcutsIntegration`: App Intents.
- `Storage`: persistence, import/export.
- `Analytics`: local event queue and privacy controls.

### Storage
MVP:
- SQLite or SwiftData for app data.
- JSON export/import for portability.
- Security-scoped bookmarks for files/folders.
- Store window layout snapshots as structured records.

Context model:
- ID, name, icon, color.
- Pinned state.
- Apps list.
- Resource list.
- Window layout snapshot.
- Hide/quit actions.
- Shortcut actions.
- Cleanup policy.
- Last run health.

### Window Management
Use:
- CGWindow APIs to observe visible windows and metadata.
- Accessibility APIs to move/resize windows and inspect app windows.
- NSWorkspace for launching/opening.
- App-specific Apple Events only where user granted permission.

Constraints:
- Cannot reliably control all Spaces.
- Cannot always restore full-screen windows.
- Some apps ignore programmatic resize.
- Browser tabs are app-specific and fragile.
- Window IDs are not stable across launches.

Strategy:
- Match windows by app bundle ID, title heuristics, role, screen, and approximate frame.
- Store display profile: display UUID/name, resolution, scale, arrangement.
- Restore after app launch with retry/backoff.
- Show confidence and failures.

### Menu Bar
- Prefer AppKit `NSStatusItem` for maximum control.
- SwiftUI content hosted in `NSPopover`.
- Optional SwiftUI `MenuBarExtra` can be evaluated, but AppKit likely needed for richer panel behavior.

### MVP Without Overengineering
Ship:
- Local-only storage.
- Manual contexts.
- Best-effort window restore.
- Menu bar switching.
- Templates.
- Permissions center.
- Import/export.
- Basic App Intent run support.

Delay:
- Sync.
- AI suggestions.
- Community gallery.
- Location rules.
- Complex app plugins.

---

## 17. macOS-Specific Edge Cases

### Multiple Monitors
- Store display profile per context.
- If missing display, remap windows to primary display proportionally.
- Show “External display missing” warning.
- Let user save alternate layouts.

### Different Resolutions
- Store normalized frames and absolute frames.
- Prefer normalized restore when display changed.
- Clamp windows to visible bounds.

### Spaces
- Do not promise exact Space restoration.
- If app is assigned to a Space by macOS/Dock, respect system behavior.
- Educate: “Spaces are controlled by macOS; Contexts restores windows in the current available workspace.”

### Full-Screen Apps
- Detect but avoid forcing.
- Offer “Open app” rather than “restore full-screen state.”
- Warn if full-screen restoration is unavailable.

### Closed Apps
- Launch via NSWorkspace.
- Wait for activation.
- Retry window detection.
- Fall back to app opened but layout incomplete.

### Missing Files
- Mark resource as missing.
- Offer Locate, Remove, or Skip.
- Do not block entire context.

### Browser Tabs
MVP: open URLs, not restore exact tab groups.
V1.5: support browser profiles/tab groups where stable.
Avoid promising exact Arc/Chrome/Safari workspace state unless app-specific APIs allow it.

### Permission Revocation
- Detect on next run.
- Continue non-permission actions.
- Show repair banner.

### App Updates
- Bundle ID may remain, window titles/behavior may change.
- Relearn layout on failed restore.
- Add app-specific notes in diagnostics.

### Partial Failure
Run result states:
- Complete.
- Mostly restored.
- Needs attention.
- Failed safely.

### Rollback
Store previous visible window frames before run.
Undo can:
- Reopen hidden apps.
- Restore moved windows where still available.
- Cannot reliably close apps opened by user after run.

---

## 18. Launch Strategy

### Ideal First Audience
Developers and technical creators with external monitors.

Why:
- High pain.
- High willingness to pay.
- Comfortable granting Accessibility.
- Strong word of mouth.
- Easy demo: code setup before/after.

### Beta
- 30-50 private alpha users.
- 300-500 TestFlight beta.
- Recruit from indie Mac, developer, creator, and productivity communities.
- Ask users to submit failed restore diagnostics.

### Communities
- X/Twitter Mac dev and productivity circles.
- Reddit: r/macapps, r/MacOS, r/productivity, r/webdev, r/Swift.
- Indie Hackers.
- Designer/dev Discords.
- Setapp-style Mac utility reviewers.
- YouTubers focused on Mac productivity.

### Content
Best demo:
- Messy desktop.
- Click “Coding.”
- VS Code, Terminal, browser docs, Linear issue appear.
- Slack hides.
- Timer starts.
- Menu bar shows active Coding.

### Product Hunt
Use after beta reliability is strong.
Position as:
“Modes for your Mac: save and restore complete work setups.”

### App Store Screenshots
1. Menu bar switcher.
2. Coding context setup.
3. Window restore before/after.
4. Templates.
5. Setup Health.
6. Shortcuts integration.
7. Active Deep Work session.

### Website Hero
Use actual macOS screenshots or high-fidelity app captures.
Avoid abstract productivity art.

---

## 19. Roadmap

### 30-Day Prototype
Build:
- Menu bar item.
- Create context from open apps.
- Launch apps/files/URLs.
- Basic window capture/restore.
- Local JSON persistence.
- Accessibility prompt.
- Simple SwiftUI context list.

Cut:
- Billing.
- Templates gallery polish.
- App Intents.
- Sync.
- Widgets.

### 90-Day MVP
Build:
- Polished onboarding.
- Context library.
- Menu bar quick switch.
- Window restore engine v1.
- Permission center.
- Templates.
- Run confirmation sheet.
- Import/export.
- Trial/paywall.
- Crash/error logging.
- Basic App Intent.

### 6-Month Roadmap
- Calendar suggestions.
- Display profiles.
- Session history.
- Cleanup contexts.
- Widgets if validated.
- Better browser support.
- More templates.
- App-specific restore improvements.

### 12-Month Roadmap
- iCloud sync.
- Companion iPhone remote.
- Shared templates.
- Advanced rules.
- Local suggestion engine.
- Team/family packaging if demand exists.

### What Not To Build
- Full scripting language.
- Community marketplace at launch.
- AI agent that controls the Mac.
- Exact Spaces replacement.
- Heavy project management features.
- Social/streak mechanics.

---

## 20. Risks And Failure Modes

| Risk | Failure Mode | Mitigation |
|---|---|---|
| Too complex | Users abandon setup | Template-first onboarding; progressive disclosure |
| Permissions scare users | Accessibility denied | Plain messaging, local-first trust, partial value without permission |
| Window restore unreliable | Users churn | Best-effort language, health checks, diagnostics, app-specific heuristics |
| Too niche | Small market | Start with developers, expand to writers/creators/students |
| Easy to copy | Launcher/window managers add similar feature | Win on trust, UX, reliability, templates, lifecycle |
| Apple sherlocking | Stage Manager adds saved stages | Differentiate with files, URLs, Focus, cleanup, templates, pro workflows |
| Poor onboarding | No aha | First context from current setup, test run in onboarding |
| Automation feels unsafe | Fear of chaos | Confirmation sheets, preview, undo, no destructive defaults |
| Support burden | Many app-specific failures | Diagnostics, known app notes, beta telemetry, scoped promises |
| Monetization mismatch | Users reject subscription | Offer lifetime purchase and transparent macOS maintenance rationale |

---

## 21. Final Recommendation

### Best MVP Definition
A premium menu bar Mac app that lets users create named contexts, launch apps/files/URLs, capture and restore window layouts best-effort, hide distractions, and switch from the menu bar or keyboard with a clear permissions health system.

### Best Pricing Model
14-day full-feature trial, then Contexts Pro at $39/year launch pricing plus $89 lifetime launch pricing. Raise to $49/year and $129 lifetime after early adoption.

### Best Initial Audience
Developers and technical creators using external displays who switch between Coding, Meetings, Admin, and Deep Work daily.

### Best Positioning
Primary: **Modes for your Mac.**  
Secondary: **Your Mac, ready for what you’re doing.**

### Best Retention Loop
Pinned menu bar contexts become daily muscle memory; users accumulate project-specific setups that save time and feel personal.

### Biggest Moat
Reliable, trustworthy, native context restoration with graceful failure handling and a growing template/app-specific knowledge base.

### Biggest Technical Risk
Window restoration reliability across apps, displays, Spaces, full-screen states, and macOS permission changes.

### Signature Hook
**“Save your current Mac setup as a context, then restore it from the menu bar in one click.”**
