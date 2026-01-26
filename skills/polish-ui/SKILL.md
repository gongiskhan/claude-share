---
name: polish-ui
description: Improve visual design and UX of artifact with iterative refinements
---

# Polish UI Skill

## Purpose

This skill improves the visual design, user experience, and polish of an artifact through iterative refinements. It focuses on making the UI look professional, feel responsive, and follow design best practices.

## When to Use

- **ALWAYS** use this skill when the "Visual Polish" refinement is enabled
- After the artifact implementation is complete
- After any testing phase (if enabled)
- When the UI is functional but needs visual improvements

## Instructions

### Step 1: Audit Current UI

Review the artifact and evaluate these aspects:

| Aspect | What to Check |
|--------|--------------|
| **Visual Hierarchy** | Is the most important content prominent? |
| **Spacing** | Is there consistent padding and margins? |
| **Typography** | Are font sizes, weights, line heights appropriate? |
| **Colors** | Is contrast sufficient? Are colors harmonious? |
| **Alignment** | Are elements properly aligned? |
| **Responsiveness** | Does it work on all screen sizes? |
| **Interactions** | Are hover/focus/active states clear? |
| **Accessibility** | Are there focus indicators? Color contrast? |
| **Loading States** | Are loading/empty states handled? |
| **Animations** | Are transitions smooth and purposeful? |

### Step 2: Prioritize Improvements

Create a prioritized list of improvements:

**High Priority (Must Fix):**
- Broken layouts
- Unreadable text (contrast issues)
- Missing responsive breakpoints
- No interactive feedback

**Medium Priority (Should Fix):**
- Inconsistent spacing
- Poor visual hierarchy
- Missing hover states
- Typography improvements

**Low Priority (Nice to Have):**
- Micro-animations
- Advanced transitions
- Subtle shadows/depth
- Icon consistency

### Step 3: Apply Improvements

For each iteration:

1. **Start with structural issues**
   - Fix layout problems
   - Add responsive breakpoints
   - Establish grid/spacing system

2. **Then typography**
   - Set font hierarchy (headings, body, captions)
   - Improve line heights and letter spacing
   - Ensure readability

3. **Then colors and contrast**
   - Check and fix contrast ratios
   - Apply consistent color palette
   - Add subtle color variations for depth

4. **Then interactive states**
   - Add hover effects
   - Add focus indicators
   - Add transition animations

5. **Finally polish details**
   - Add subtle shadows
   - Refine border radius
   - Add micro-interactions

### Step 4: Verify Improvements

After each iteration:
- Visually inspect the changes
- Check responsiveness at different sizes
- Ensure functionality is preserved
- Run any existing tests if available

### Step 5: Report Progress

Report each iteration:
"UI Polish Phase - Iteration X/Y"
"Applied improvements: [list of changes]"
"Remaining items: [list of pending improvements]"

## Input Expected

- Built artifact with functional UI
- Company branding guidelines (if provided)
- Max iterations for refinements (from config)

## Output Expected

1. List of identified issues
2. Changes applied per iteration
3. Final polish summary
4. Any remaining recommendations

## Iteration Handling

Each iteration should focus on a coherent set of improvements:

**Iteration 1: Foundation**
- Layout structure
- Responsive breakpoints
- Basic spacing system

**Iteration 2: Visual Refinement**
- Typography improvements
- Color adjustments
- Visual hierarchy

**Iteration 3+: Polish Details**
- Interactive states
- Animations
- Final touches

**Progress Reporting:**
"UI Polish Phase - Iteration X/Y - Improving [aspect]..."

**Exit Conditions:**
- All high/medium priority items addressed -> Success
- Max iterations reached -> Report remaining items
- No more improvements identified -> Complete early

## Design Principles to Follow

### Spacing
- Use consistent spacing scale (e.g., 4, 8, 16, 24, 32, 48px)
- More space around important elements
- Group related items with less space between them

### Typography
- Limit to 2-3 font sizes per page
- Use font weight for emphasis, not just size
- Line height: 1.5 for body text, 1.2 for headings

### Colors
- Primary color for main actions
- Neutral colors for most text
- Accent colors sparingly for emphasis
- Ensure 4.5:1 contrast ratio minimum

### Interactions
- Hover states should be subtle but noticeable
- Focus states must be visible for accessibility
- Transitions should be 150-300ms
- Avoid animation on essential interactions

### Responsive Design
- Mobile-first approach
- Breakpoints: 640px, 768px, 1024px, 1280px
- Touch targets: minimum 44x44px on mobile
- Stack layouts vertically on mobile

## Examples

### Example 1: Card Component Polish

**Before:**
- Card with no shadow
- Text too close to edges
- No hover effect
- Inconsistent spacing

**After (Iteration 1):**
- Added subtle box-shadow
- Added 16px padding
- Added hover shadow elevation
- Consistent 12px gap between elements

**After (Iteration 2):**
- Refined typography hierarchy
- Added transition on hover (0.2s ease)
- Improved border-radius consistency
- Added subtle background color change on hover

### Example 2: Form Polish

**Before:**
- Inputs touching each other
- No focus states visible
- Error text same size as labels
- Submit button plain

**After (Iteration 1):**
- Added 16px vertical spacing between fields
- Added focus ring on inputs
- Styled error text in red, smaller size
- Added hover/active states to button

**After (Iteration 2):**
- Added subtle input shadows
- Refined label typography
- Added transition on focus
- Added loading state to button
- Improved form layout on mobile

## CSS Patterns to Apply

### Consistent Shadows
```css
--shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
--shadow-md: 0 4px 6px rgba(0,0,0,0.1);
--shadow-lg: 0 10px 15px rgba(0,0,0,0.1);
```

### Smooth Transitions
```css
transition: all 0.2s ease-in-out;
```

### Focus States
```css
:focus-visible {
  outline: 2px solid var(--primary-color);
  outline-offset: 2px;
}
```

### Hover Effects
```css
.card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-lg);
}
```

## Framer Motion Animation Patterns (for React/Next.js projects)

If the project uses Framer Motion, apply these animation patterns for professional polish:

### Check for Framer Motion
First, check if `framer-motion` is in `package.json` dependencies. If present, use these patterns:

### Page Transitions
Add entrance animations to page components:
```tsx
import { motion } from 'framer-motion';

// Wrap page content
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.4, ease: 'easeOut' }}
>
  {/* page content */}
</motion.div>
```

### Staggered List Animations
For lists of items (cards, menu items, table rows):
```tsx
const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 }
  }
};

const item = {
  hidden: { opacity: 0, y: 10 },
  show: { opacity: 1, y: 0 }
};

<motion.ul variants={container} initial="hidden" animate="show">
  {items.map((i) => (
    <motion.li key={i.id} variants={item}>{i.name}</motion.li>
  ))}
</motion.ul>
```

### Interactive Hover Effects
For buttons, cards, and clickable elements:
```tsx
<motion.button
  whileHover={{ scale: 1.02 }}
  whileTap={{ scale: 0.98 }}
  transition={{ type: 'spring', stiffness: 400, damping: 17 }}
>
  Click me
</motion.button>
```

### Card Hover Lift
```tsx
<motion.div
  whileHover={{ y: -4, boxShadow: '0 10px 30px rgba(0,0,0,0.12)' }}
  transition={{ duration: 0.2 }}
  className="card"
>
  {/* card content */}
</motion.div>
```

### Loading Skeleton Pulse
```tsx
<motion.div
  animate={{ opacity: [0.5, 1, 0.5] }}
  transition={{ duration: 1.5, repeat: Infinity }}
  className="skeleton"
/>
```

### Exit Animations
For elements leaving the DOM:
```tsx
import { AnimatePresence, motion } from 'framer-motion';

<AnimatePresence>
  {showItem && (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0, y: -10 }}
    >
      Content
    </motion.div>
  )}
</AnimatePresence>
```

### Animation Best Practices

| Principle | Guideline |
|-----------|-----------|
| **Subtlety** | Keep animations under 400ms for UI interactions |
| **Spring physics** | Use `type: 'spring'` for natural feel |
| **Purposeful** | Only animate meaningful state changes |
| **Performance** | Stick to `transform` and `opacity` |
| **Accessibility** | Respect `prefers-reduced-motion` |

### Animation Polish Checklist

When evaluating animations in an artifact:

- [ ] Page transitions feel smooth (not jarring)
- [ ] Lists have staggered entrance animation
- [ ] Buttons have hover/tap feedback
- [ ] Cards lift slightly on hover
- [ ] Loading states are animated
- [ ] Modals/dialogs animate in/out
- [ ] Animations are not excessive or distracting
- [ ] Exit animations are present where needed

### When to Add Animations

**DO add animations for:**
- Page load content appearance
- List item entrances
- Button hover/tap feedback
- Card hover states
- Modal/dialog transitions
- Toast/notification entrances
- Loading state indicators

**DON'T add animations for:**
- Every single element (too distracting)
- Critical error states (should be immediate)
- Frequent repeated actions (becomes annoying)
- Very short content changes

## Important Notes

- **Never break functionality** - Polish should only improve appearance
- **Test after changes** - Verify the app still works correctly
- **Respect existing design system** - Don't introduce conflicting styles
- **Apply company branding** - Use provided colors, fonts, and guidelines
- **Be subtle** - Good polish is often invisible, bad polish is distracting
- **Prioritize impact** - Focus on what users will notice most
