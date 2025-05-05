## Locating Theme Configuration

Glance theme settings are defined within the main configuration file, typically `/mnt/c/Users/NamVice/Documents/Personal/Zettelkasten/Manifests/ansible/services/glance/roles/common/files/config/glance.yml`. Theme customization is managed under a top-level `theme:` key in this YAML file. If this key is absent, Glance uses its default theme.

## Defining Custom Theme Properties

The `theme:` block accepts several properties to control the visual appearance. Colors are specified using the HSL (Hue, Saturation, Lightness) model, represented as three space-separated numbers (e.g., `240 21 15`). Hue is an angle from 0-360, while Saturation and Lightness are percentages from 0-100.

*   `background-color`: Sets the primary background color for the dashboard interface using HSL values.
*   `primary-color`: Defines the main accent color used for highlights, links, and interactive elements, specified in HSL.
*   `positive-color`: Determines the color used for success indicators, such as the 'OK' status in monitor widgets, using HSL.
*   `negative-color`: Sets the color for error or failure indicators, like the 'ERROR' status in monitor widgets, also in HSL.
*   `contrast-multiplier`: A numerical value (e.g., `1.1`, `1.2`) that adjusts the overall contrast between text and background elements. Values greater than 1 increase contrast.
*   `light`: A boolean value (`true` or `false`). Setting this to `true` designates the theme as a light theme, adjusting text and element rendering accordingly. If omitted or set to `false`, it's treated as a dark theme.
*   `text-saturation-multiplier`: A numerical value (e.g., `0.5`) that modifies the saturation of text elements relative to the defined colors.

To implement a custom theme, you add the `theme:` block to your `glance.yml` and specify the desired properties with their corresponding HSL values or multipliers. For example, the Catppuccin Mocha theme is defined as:

```yaml
theme:
  background-color: 240 21 15
  contrast-multiplier: 1.2
  primary-color: 217 92 83
  positive-color: 115 54 76
  negative-color: 347 70 65
```

## Finding Predefined Themes and Documentation

The definitive source for predefined themes and detailed explanations of the theme properties is the official Glance documentation hosted on GitHub. You can find a list of available themes with their configurations and visual previews in the `themes.md` file within the repository.

Reference: [https://github.com/glanceapp/glance/blob/main/docs/themes.md](https://github.com/glanceapp/glance/blob/main/docs/themes.md)

This document provides the necessary HSL values and configuration examples for various popular themes like Gruvbox, Catppuccin variants, Dracula, and others, serving as a practical starting point for customization.

## Layout Configuration

Glance allows flexible layout customization through the `pages`, `columns`, and `widgets` structure within the configuration file (`glance.yml`).

### Pages

The top-level structure starts with a list under the `pages:` key. Each item in this list represents a distinct page on the dashboard.

*   `name`: (String) The title displayed for the page, often shown in navigation.
*   `width`: (Enum: `slim`, `medium`, `wide`, `full`, Default: `medium`) Controls the maximum overall width of the page content container.
*   `hide-desktop-navigation`: (Boolean, Default: `false`) If set to `true`, the page navigation links (if multiple pages exist) are hidden on larger screens.
*   `center-vertically`: (Boolean, Default: `false`) When `true`, Glance attempts to vertically center the page's content within the viewport.
*   `columns`: (List) Defines the columns that make up the page layout.

Example Page Definition:

```yaml
pages:
  - name: Dashboard
    width: slim
    hide-desktop-navigation: true
    center-vertically: true
    columns:
      # ... column definitions go here ...
```

### Columns

Within each page, the `columns:` list defines the vertical sections. The available horizontal space is divided among these columns based on their `size`.

*   `size`: (Enum: `small`, `medium`, `large`, `full`) Specifies the relative width of the column. `full` attempts to occupy the remaining available space after other columns are sized. Multiple columns can be defined.
*   `widgets`: (List) Contains the list of widgets to be displayed within this column, rendered vertically in the order they are listed.

Example Column Structure (within a page):

```yaml
    columns:
      - size: small # Left column
        widgets:
          # ... widgets for the left column ...
      - size: full # Right column (takes remaining space)
        widgets:
          # ... widgets for the right column ...
```

### Widgets

Widgets are the core content blocks placed within columns. They are defined as a list under the `widgets:` key in a column definition.

*   `type`: (String, Required) Specifies the kind of widget (e.g., `clock`, `calendar`, `weather`, `monitor`, `bookmarks`).
*   Other keys depend on the widget `type`. For instance, `monitor` widgets have `title`, `cache`, and `sites` (a list of sites with `title`, `url`, `icon`). `weather` has `location`.

Refer to the official Glance documentation for specific configuration options available for each widget type.