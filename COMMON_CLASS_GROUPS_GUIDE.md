# Common Class Groups - Developer Guide

## Overview
Common Class Groups (CCG) provide reusable, consistent UI components across all RML widgets. Think of them as a design system that bundles utility classes into semantic, copy-pasteable components.

## Core Principles

### 1. **Consistency Over Customization**
- Use CCG components for standard UI elements (buttons, text, cards, etc.)
- Only create custom styling when CCG doesn't provide what you need
- Every "primary button" should look identical across all widgets

### 2. **Semantic Naming**
- CCG uses semantic names: `primary`, `success`, `warning`, `danger`
- Avoid hard-coding colors or specific styles in your templates
- Let the theme system handle color variations

### 3. **Extension, Not Replacement**
- Extend CCG classes with additional utilities: `ccg.button.primary + ' mt-4 w-full'`
- Always include a leading space when extending: `+ ' additional-classes'`
- Never replace CCG classes entirely unless absolutely necessary

## Usage Rules

### ✅ **DO**

#### Use CCG for Standard Components
```rml
<!-- Buttons -->
<button data-attr-class="ccg.button.primary">Save</button>
<button data-attr-class="ccg.themeButton.ghost">Cancel</button>

<!-- Text -->
<span data-attr-class="ccg.text.error">Error message</span>
<h2 data-attr-class="ccg.heading.h4">Section Title</h2>

<!-- Tags/Indicators -->
<span data-attr-class="ccg.badge.success">Online</span>
<span data-attr-class="ccg.pill.warning">Alert</span>
<span data-attr-class="ccg.circle.danger">!</span>
```

#### Extend with Utility Classes
```rml
<!-- Add spacing and layout -->
<button data-attr-class="ccg.button.primary + ' mt-4 mb-2 w-full'">
<div data-attr-class="ccg.card.default + ' flex flex-col gap-4'">
```

#### Use Widget Initialization
```lua
-- In your widget's Initialize function
utils.initializeRmlWidget(self, {
    useCommonClassGroups = true,
    -- other params...
})
```

#### Create Custom Class Groups for Widget-Specific Components
```lua
-- In your init_model
my = {
    specialCard = {
        container = "flex flex-col p-4 bg-darker rounded",
        title = ccg.definitions.themeText.subheading .. " mb-2",
        content = ccg.definitions.text.body
    }
}
```

### ❌ **DON'T**

#### Avoid Hard-Coding Colors
```rml
<!-- BAD -->
<button class="bg-red text-white">Delete</button>

<!-- GOOD -->
<button data-attr-class="ccg.button.danger">Delete</button>
```

#### Don't Forget Leading Spaces in Extensions
```rml
<!-- BAD - Will concatenate incorrectly -->
<div data-attr-class="ccg.card.primary + 'mt-4'">

<!-- GOOD - Proper spacing -->
<div data-attr-class="ccg.card.primary + ' mt-4'">
```

#### Don't Mix Class and Data-Attr-Class
```rml
<!-- BAD - Inconsistent approach -->
<button class="p-3" data-attr-class="ccg.button.primary">

<!-- GOOD - Use data-attr-class for everything -->
<button data-attr-class="ccg.button.primary + ' p-3'">
```

## Component Categories

### **Buttons**
- `ccg.button.*` - Theme-agnostic buttons
- `ccg.themeButton.*` - Theme-aware buttons
- Use semantic variants: `default`, `primary`, `success`, `warning`, `danger`, `ghost`

### **Text & Typography**
- `ccg.text.*` - Fixed semantic colors
- `ccg.themeText.*` - Theme-adaptive colors
- `ccg.heading.*` - Semantic headings (h1-h6) with margins

### **Tags & Indicators**
- `ccg.badge.*` - Rectangular status indicators
- `ccg.pill.*` - Rounded status indicators  
- `ccg.circle.*` - Circular indicators with fixed dimensions

### **Layout Components**
- `ccg.card.*` - Content containers
- `ccg.sheet.*` - Full-screen layouts (container, title, content, footer)
- `ccg.panel.*` - Specialized themed panels
- `ccg.nav.*` - Navigation containers

## Architecture Patterns

### **Theme Compatibility**
- Use `themeButton`, `themeText` variants for theme-aware components
- Use standard `button`, `text` variants for consistent cross-theme appearance
- Construction/industrial themes use hazard patterns automatically

### **Responsive Extension**
```rml
<!-- Scale components with utility classes -->
<span data-attr-class="ccg.badge.primary + ' text-lg'">
<div data-attr-class="ccg.card.default + ' w-full h-48'">
```

### **Nested Component References**
```lua
-- Reference CCG definitions in custom components
my = {
    customCard = {
        title = ccg.definitions.themeText.heading,
        subtitle = ccg.definitions.text.caption .. " text-muted"
    }
}
```

## Development Workflow

### **1. Design Phase**
- Check style guide widget for existing components
- Identify which CCG categories fit your needs
- Plan custom extensions before coding

### **2. Implementation**
- Start with base CCG component
- Add utility classes for layout/spacing
- Test across different themes

### **3. Validation**
- Ensure consistent appearance with other widgets
- Verify theme compatibility
- Check copy-paste functionality for other developers

## Advanced Patterns

### **Composite Components**
```lua
-- Create reusable composite components
my = {
    statusCard = {
        container = ccg.definitions.card.default .. " flex items-center gap-3",
        icon = ccg.definitions.circle.success,
        title = ccg.definitions.themeText.heading,
        description = ccg.definitions.text.body .. " text-muted"
    }
}
```

### **Conditional Styling**
```rml
<!-- Use data model for dynamic CCG selection -->
<button data-attr-class="(isActive ? ccg.button.primary : ccg.button.default) + ' w-full'">
```

### **Theme-Aware Custom Components**
```lua
-- Reference theme colors in custom components
my = {
    alertBox = {
        success = ccg.definitions.panel.default .. " border-success-alpha",
        warning = ccg.definitions.panel.construction .. " border-warning",
        error = ccg.definitions.panel.danger .. " border-danger-alpha"
    }
}
```

## Style Guide Integration

### **Documentation**
- Use the RML Style Guide widget to browse available components
- Copy examples directly from the style guide
- Reference real implementations for complex patterns

### **Extending the System**
- Add new CCG components to `common_class_groups.lua`
- Update style guide examples when adding new components
- Follow existing naming conventions and semantic patterns

---

## Quick Reference

**Essential CCG Groups:**
- `ccg.button.*` / `ccg.themeButton.*`
- `ccg.text.*` / `ccg.themeText.*`  
- `ccg.heading.*`
- `ccg.badge.*` / `ccg.pill.*` / `ccg.circle.*`
- `ccg.card.*` / `ccg.sheet.*` / `ccg.panel.*`

**Extension Pattern:**
```rml
data-attr-class="ccg.component.variant + ' utility-classes'"
```

**Widget Setup:**
```lua
utils.initializeRmlWidget(self, { useCommonClassGroups = true })
```

**Custom Components:**
```lua
my = { customComponent = { ... } }
```