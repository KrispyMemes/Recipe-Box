# Recipe App - Product Spec v1

## 1. Product Goal
Build a personal recipe manager for iOS, iPadOS, macOS, and Windows with one shared codebase.

Primary value:
- Capture recipes from anywhere
- Pin recipes for the current week
- Automatically compile a shopping list from pinned recipes
- Work fully offline and sync when online

## 2. Target Users
- Primary: Single user (owner)
- Secondary: One additional person using shared credentials

## 3. Platform and Tech Decisions (Locked)
- Client: Flutter (single codebase)
- Backend: Supabase (Auth, Postgres, Storage)
- App behavior: Local-first, offline-capable, background sync
- Browser capture: Chromium extension (v1 basic capability)

## 4. In Scope (v1)
### Core Screens
1. Recipe Library
2. Recipe Detail/Edit
3. Import Center (URL import, photo/OCR import, share import inbox)
4. Pinned This Week
5. Shopping List
6. Settings (sync/account/basic app preferences)

### Core Features
1. Create, edit, delete recipes
2. Recipe thumbnails, titles, tags, and collections
3. Fast pin/unpin for weekly planning
4. Auto-generate shopping list from pinned recipes
5. Import from URL (recipe page parsing)
6. Import from photo/OCR
7. Receive shared content into app import inbox (where platform allows)
8. Offline read/write on all core features
9. Cloud sync conflict-safe enough for low-volume personal use

## 5. Out of Scope (v1)
1. Full meal-planning calendar/menu system
2. Built-in in-app browser
3. Advanced household collaboration with roles/permissions
4. Walmart+ or other grocery checkout integrations
5. Public marketplace/social sharing

## 6. UX Principles
1. Weekly pinning is first-class (not hidden in nested menus)
2. Import should be frictionless and visible from all key screens
3. Categories are replaced by clearer structure:
   - Collections (user-defined groupings)
   - Tags (lightweight labels)
   - Search + filters
4. Mobile and desktop layouts should both feel intentional, not stretched copies

## 7. Core User Flows
### Flow A: Import from URL
1. User pastes URL or uses browser extension
2. App parses title, ingredients, steps, image, metadata
3. User reviews/edits parsed fields
4. User saves recipe to library

Acceptance:
- Save succeeds offline after edit (queued sync when online)
- User can add tags/collection during save

### Flow B: Import from Photo/OCR
1. User takes/selects photo
2. OCR extracts text
3. App attempts structure detection (ingredients vs steps)
4. User corrects and saves

Acceptance:
- OCR result is editable before save
- Original image is retained for later reference

### Flow C: Weekly Planning (Primary)
1. User browses library
2. User pins recipes to "This Week"
3. Pinned screen shows selected recipes with quick reorder/remove
4. User generates/refreshes shopping list from pinned items

Acceptance:
- Pin/unpin is one tap/click from library and detail views
- Pinned list is accessible from top-level navigation

### Flow D: Shopping List Build
1. App aggregates ingredients across pinned recipes
2. Similar ingredients are grouped (best-effort normalization)
3. User checks off or edits items

Acceptance:
- List can be regenerated without losing manually added custom items
- User can view source recipe for each list item

### Flow E: Offline + Sync
1. User edits data while offline
2. Changes are stored locally
3. On reconnect, sync runs in background

Acceptance:
- No blocking errors when offline for core CRUD
- Last-write-wins conflict policy documented for v1

## 8. Data Model (v1 level)
### Entities
1. Recipe
2. Ingredient
3. InstructionStep
4. RecipeImage
5. Tag
6. Collection
7. WeeklyPin
8. ShoppingList
9. ShoppingListItem
10. ImportJob (url/photo/share payload + parse status)

### Required Recipe Fields
- id (UUID)
- title
- description (optional)
- servings (optional)
- total_time_minutes (optional)
- source_url (optional)
- thumbnail_url (optional)
- created_at, updated_at
- sync_version / updated_at for conflict handling

## 9. Quality of Life Priorities (v1)
1. Better pinning workflow than Paprika
2. Better share/import capture surfaces
3. Cleaner organization than legacy "categories"
4. Fast browse experience with thumbnails and title-first cards

## 10. Non-Functional Requirements
1. Offline-first for all core actions
2. Sync reliability over real-time complexity
3. Reasonable performance with at least 2,000 recipes
4. Import operations should not freeze UI

## 11. Integration Strategy
### Browser Extension (Chromium)
v1 behavior:
1. "Save to Recipe App" on current tab
2. Sends URL + page metadata to app/backend import endpoint
3. Recipe lands in Import Center for review

### iOS Share Target
v1 behavior:
1. Accept shared URL/text/image where platform supports it
2. Create ImportJob in app inbox
3. User reviews and confirms

## 12. Risk Register (v1)
1. Recipe parsing variability across sites
   - Mitigation: review/edit step always required
2. OCR quality inconsistency
   - Mitigation: keep image and manual correction workflow
3. Cross-platform sharing edge cases
   - Mitigation: Import Center queue as fallback
4. Sync conflict complexity
   - Mitigation: simple last-write-wins in v1, log conflicts

## 13. v1 Success Criteria
1. User can import a recipe from URL, edit, and save
2. User can import from photo/OCR and save
3. User can pin recipes for the week quickly
4. User can generate a usable shopping list from pinned recipes
5. App remains usable without internet
6. Data syncs across at least two devices on same account

## 14. Next Build Milestones
1. Milestone 1: Flutter project + navigation skeleton + local DB schema
2. Milestone 2: Recipe CRUD + library UI + tags/collections
3. Milestone 3: Weekly pinning + shopping list aggregation
4. Milestone 4: URL import pipeline + Import Center
5. Milestone 5: OCR/photo import
6. Milestone 6: Sync hardening + cross-device testing
7. Milestone 7: Chromium extension basic capture
