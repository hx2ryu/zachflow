# Screen Spec: {ScreenName}

> Machine-readable screen specification. The Design Engineer agent reads this file to generate the HTML prototype.
> All fields are structured — no prose.

## Meta

```yaml
screen_name: "{ScreenName}"
screen_archetype: "{feed | detail | onboarding | form | modal | empty_state | nav_list}"
modal_subtype: "{dialog | picker | action_sheet | sheet | null}"  # modal archetype only — picker/action_sheet exempts modal #3. null for non-modal archetypes.
detail_state: "{normal | blocked | private | restricted | unavailable}"  # detail archetype only — non-blocked variants exempt detail #4. Defaults to normal.
task_id: "{task-id}"
sprint_id: "{sprint-id}"
app: "{app-name}"
platform: "{e.g. iOS / Android (React Native) | Web}"
language: "{e.g. en, ko}"
frame: "{viewport WxH, e.g. 390x844 for iPhone-class}"
theme: "{light | dark}"
instant_save: false  # form archetype only — set true when toggle/checkbox autosaves on change (exempts form persona #2/#4).
```

**`screen_archetype` selection guide** (pick exactly one — the dominant pattern):

| archetype | Core signal | Examples |
|-----------|-------------|----------|
| **feed** | N homogeneous items in a scroll | Home feed, search results, notification list |
| **detail** | Single object detail (hero + body + CTAs) | Post detail, profile page, product detail |
| **onboarding** | Multi-step progress + large primary CTA | Sign-up step 1/2/3, tutorial, setup wizard |
| **form** | Input fields + validation + submit | Login, report, edit profile |
| **modal** | Partial-screen + backdrop + dismiss | Confirm, share sheet, filter sheet |
| **empty_state** | Zero content + 1 primary CTA | Empty feed, no search results, first-run |
| **nav_list** | N homogeneous nav rows + grouping + right-side affordance | Settings home, account menu, help index |

**`instant_save` flag**: meaningful only on form archetype. When `true`, exempts form persona #2 (submit disabled) / #4 (single primary). See `.claude/teammates/design-engineer-archetypes/form.md > Exemption (Instant Save)`.

For composite screens (e.g. detail + bottom form), classify by the dominant visual area. Ambiguous cases — ask the Sprint Lead.

**`modal_subtype` flag**: meaningful only on modal archetype. `picker` or `action_sheet` exempts modal persona #3 (single primary). See `.claude/teammates/design-engineer-archetypes/modal.md > Exemption (Picker / Action Sheet)`.

**`detail_state` flag**: meaningful only on detail archetype. Any value other than `normal` (`blocked` / `private` / `restricted` / `unavailable`) exempts detail persona #4 (single primary). See `.claude/teammates/design-engineer-archetypes/detail.md > Exemption (Blocked / Restricted Variant)`.

DE reads `screen_archetype` and applies the persona rules from `.claude/teammates/design-engineer-archetypes/{archetype}.md` (full rules in design-engineer.md Step C).

## Component Tree

Indent to express hierarchy. Each node uses the form `ComponentName [type] (tag) #id — description`.

```
Screen [frame: {viewport}]
├── StatusBar [system] (div) #status-bar
├── Header [container] (header) #header
│   ├── BackButton [icon-button] (button) #back-button — back navigation
│   ├── Title [text] (h1) #title — "{screen title}"
│   └── ActionButton [icon-button] (button) #action-button — {action description}
├── Body [scroll-container] (main) #body
│   ├── {SectionName} [container] (section) #{section-id}
│   │   ├── {ComponentName} [type] (tag) #{id} — {description}
│   │   └── ...
│   └── ...
├── BottomAction [container] (div) #bottom-action — (only when present)
│   └── CTAButton [button-primary] (button) #cta-button — "{button text}"
└── BottomNav [navigation] (nav) #bottom-nav — (only when present)
```

### Component Details

Define each component's properties.

```yaml
components:
  - name: "{ComponentName}"
    id: "{html-element-id}"
    tag: "{header | main | nav | section | div | button | h1 | p | img | input | ul | li | span}"
    type: "{container | text | button-primary | button-secondary | icon-button | image | input | list | grid | tabs | chip | badge | toggle | bottom-sheet | avatar | card | divider | skeleton}"
    position: "{top | center | bottom | sticky-top | sticky-bottom | overlay}"
    size: "{width}x{height} | full-width | wrap-content"
    tokens:
      fill: "{semantic.xxx | component.xxx | #HEX}"
      text: "{semantic.label.xxx}"
      border: "{semantic.line.xxx | none}"
      radius: "{xs|sm|md|lg|xl|2xl|full} ({N}px)"
      spacing: "{inner padding: N N N N}"
    children:
      - "{child component reference}"
    notes: "{anything notable}"
```

> `tag` and `id` are used in Step C when emitting HTML elements. `tokens` drive CSS styling.

### Enhanced Component Metadata

> See: design-engineer.md Step B.3 — Component-as-Data

Add the following metadata categories to each component (only those that apply):

```yaml
    # Behavioral Metadata
    behavior:
      purpose: "{why this component exists — derived from Context Engine WHY layer}"
      user_action: "{the action a user performs with this component}"
      feedback: "{feedback type: visual | haptic | navigation | toast}"

    # State Metadata
    states:
      default: "{default appearance}"
      disabled: "{disabled condition — null if always active}"
      loading: "{loading appearance — null if no loading state}"
      error: "{error appearance — null if no error state}"

    # Layout Metadata
    layout:
      direction: "{horizontal | vertical}"
      alignment: "{start | center | end | space-between}"
      sizing: "{fixed | hug | fill}"

    # Accessibility Metadata
    a11y:
      role: "{button | link | heading | img | text | list | tab | switch | ...}"
      label: "{screen-reader label}"

    # Composition Constraints
    constraints:
      min_height: "{N}px | null"
      max_lines: "{N} | null"
      truncation: "{ellipsis | fade | none}"
```

Priority order: `behavior` > `states` > `a11y` > `layout` > `constraints`

## Layout Spec

Express the overall layout as structured CSS layout hints.

```yaml
layout_spec:
  type: flex-column
  viewport: "{WxH}"
  regions:
    - id: status-bar
      height: fixed(44px)
    - id: header
      sticky: top
      height: fixed(56px)
    - id: body
      scroll: vertical
      flex: 1
      children:
        - id: "{section-id}"
          type: flex-column
          gap: "{N}px"
    - id: bottom-action
      sticky: bottom
      height: fixed(auto)
      padding: "16px 16px 34px"
    - id: bottom-nav
      sticky: bottom
      height: fixed(83px)
```

## States

Enumerate every state. Map visible/hidden components per state.

```yaml
states:
  default:
    description: "default state"
    active: true
    visible_components: [body]
    hidden_components: []

  empty:
    description: "no content"
    visible_components: [empty-state-view]
    hidden_components: [body]
    labels:
      title: "{empty-state title}"
      description: "{empty-state description}"
      cta: "{CTA button text}"

  loading:
    description: "loading"
    visible_components: [skeleton-loader]
    hidden_components: [body, empty-state-view]

  error:
    description: "error occurred"
    visible_components: [error-view]
    hidden_components: [body]
    labels:
      message: "{error message}"
      retry: "Retry"
```

## Interactions

Map user action → screen response as structured event bindings.

```yaml
interactions:
  - trigger: tap
    target: "#{element-id}"
    action: navigate
    destination: "{ScreenName}"
    transition: slide-left

  - trigger: tap
    target: "#{tab-id}"
    action: switch-tab
    destination: null
    transition: none

  - trigger: tap
    target: "#{element-id}"
    action: toggle-state
    state_key: "{state-name}"

  - trigger: tap
    target: "#{element-id}"
    action: open-overlay
    destination: "{BottomSheetName}"
    transition: slide-up

  - trigger: tap
    target: "#{close-button-id}"
    action: close-overlay
    transition: slide-down
```

## Visual Rules

Only business rules that affect the UI. Server-side logic excluded.

```yaml
rules:
  - condition: "{condition}"
    effect: "{UI change}"
    example: "{concrete example}"
```

## Labels

All copy/text shown on the screen. List exhaustively.

```yaml
labels:
  header:
    title: "{screen title}"
    back: "Back"
  body:
    section_title: "{section title}"
    placeholder: "{input field hint}"
  buttons:
    primary: "{primary button}"
    secondary: "{secondary button}"
  tabs:
    - "{tab1}"
    - "{tab2}"
  toast:
    success: "{success message}"
    error: "{error message}"
  empty_state:
    title: "{empty title}"
    description: "{empty description}"
```

## Token Map

Full mapping of design tokens used on this screen.

```yaml
tokens:
  background: "semantic.background.normal → #FFFFFF"
  text_primary: "semantic.label.normal → #212228"
  text_secondary: "semantic.label.alternative → #6B6E76"
  text_hint: "semantic.label.assistive → #8E9199"
  divider: "semantic.line.normal → #E4E5E9"
  brand: "semantic.fill.brand-primary → #8752FA"
  button_primary_fill: "component.button.primary.fill → #8752FA"
  button_primary_label: "component.button.primary.label → #FFFFFF"
  button_secondary_fill: "component.button.secondary.fill → #F0F1F3"
  card_fill: "component.card.fill → #FFFFFF"
  card_radius: "component.card.radius → 16px"
  input_fill: "component.input.fill → #F7F8F9"
  input_radius: "component.input.radius → 12px"
  nav_active: "component.navigation.bottom-bar.active → #8752FA"
  nav_inactive: "component.navigation.bottom-bar.inactive → #8E9199"
```

## Quality Score

> See: design-engineer.md Step B.5 — metadata quality score

```yaml
quality_score:
  extraction_accuracy:
    total_components: {N}
    with_token_map: {N}
    with_html_mapping: {N}
    score: "{with_token_map + with_html_mapping} / {total_components * 2}"
  fabrication_risk:
    inferred_fields: ["{fields the AI inferred without PRD basis}"]
    risk_level: "{none | low | medium | high}"
  schema_completeness:
    required_sections: ["meta", "component_tree", "layout_spec", "states", "interactions", "labels", "token_map"]
    present_sections: ["{actually authored sections}"]
    score: "{present} / {required}"
  context_coverage:
    why_linked: "{ACs with linked ui_impact} / {total ACs}"
    what_resolved: "{tokens/components confirmed} / {tokens/components needed}"
```
