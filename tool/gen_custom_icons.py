"""Generates lib/core/widgets/custom_icons.dart from the React Native icon set.

Usage: python3 tool/gen_custom_icons.py <path to CustomIcons.tsx>
The icons are plain react-native-svg JSX, so each one is converted to an SVG
string builder; flutter_svg renders it. Do not edit the output by hand.
"""
import re
import sys

KEBAB = {
    "strokeWidth": "stroke-width", "strokeLinecap": "stroke-linecap",
    "strokeLinejoin": "stroke-linejoin", "strokeOpacity": "stroke-opacity",
    "fillOpacity": "fill-opacity", "fillRule": "fill-rule", "clipRule": "clip-rule",
    "strokeDasharray": "stroke-dasharray", "strokeDashoffset": "stroke-dashoffset",
    "strokeMiterlimit": "stroke-miterlimit", "stopColor": "stop-color",
    "stopOpacity": "stop-opacity",
}
TAGS = {
    "Path": "path", "Circle": "circle", "Rect": "rect", "Line": "line",
    "Polygon": "polygon", "Polyline": "polyline", "Ellipse": "ellipse", "G": "g",
    "Defs": "defs", "LinearGradient": "linearGradient", "Stop": "stop",
}


class Parser:
    def __init__(self, s):
        self.s = s
        self.i = 0

    def ws(self):
        while self.i < len(self.s) and self.s[self.i].isspace():
            self.i += 1

    def take_braces(self):
        """Returns the text inside a balanced {...} starting at self.i."""
        assert self.s[self.i] == "{"
        depth, j = 0, self.i
        in_str = None
        while j < len(self.s):
            c = self.s[j]
            if in_str:
                if c == in_str:
                    in_str = None
            elif c in "'\"":
                in_str = c
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        inner = self.s[self.i + 1 : j]
        self.i = j + 1
        return inner

    def expr(self, text):
        t = text.strip()
        if re.fullmatch(r"-?[\d.]+", t):
            return t
        if t == "color":
            return "$c"
        m = re.fullmatch(r"focused\s*\?\s*(.+?)\s*:\s*(.+)", t)
        if m:
            return "${focused ? %s : %s}" % (self.dart(m.group(1)), self.dart(m.group(2)))
        m = re.fullmatch(r"'([^']*)'", t)
        if m:
            return m.group(1)
        raise ValueError("unsupported expression: " + t)

    def dart(self, t):
        t = t.strip()
        if t == "color":
            return "c"
        return t

    def attrs(self):
        out = []
        while True:
            self.ws()
            if self.s.startswith("/>", self.i) or self.s.startswith(">", self.i):
                return out
            m = re.compile(r"[\w:]+").match(self.s, self.i)
            name = m.group(0)
            self.i = m.end()
            if self.s[self.i] != "=":
                out.append((name, "true"))
                continue
            self.i += 1
            if self.s[self.i] in "\"'":
                q = self.s[self.i]
                j = self.s.index(q, self.i + 1)
                val = self.s[self.i + 1 : j]
                self.i = j + 1
            else:
                val = self.expr(self.take_braces())
            out.append((name, val))

    def children(self):
        parts = []
        while self.i < len(self.s):
            self.ws()
            if self.s.startswith("{/*", self.i):
                self.i = self.s.index("*/}", self.i) + 3
            elif self.s.startswith("{", self.i):
                inner = self.take_braces()
                m = re.fullmatch(r"\s*focused\s*&&\s*\(?(.*?)\)?\s*", inner, re.S)
                assert m, inner
                sub = Parser(m.group(1))
                body = "".join(sub.children())
                parts.append("${focused ? '''%s''' : ''}" % body)
            elif self.s.startswith("</", self.i):
                return parts
            elif self.s.startswith("<>", self.i):
                self.i += 2
                parts.extend(self.children())
                assert self.s.startswith("</>", self.i)
                self.i += 3
            elif self.s.startswith("<", self.i):
                parts.append(self.element())
            else:
                self.i += 1
        return parts

    def element(self):
        assert self.s[self.i] == "<"
        self.i += 1
        m = re.compile(r"\w+").match(self.s, self.i)
        name = m.group(0)
        self.i = m.end()
        attrs = self.attrs()
        tag = TAGS[name]
        a = "".join(' %s="%s"' % (KEBAB.get(k, k), v) for k, v in attrs)
        if self.s.startswith("/>", self.i):
            self.i += 2
            return "<%s%s/>" % (tag, a)
        self.i += 1  # '>'
        kids = "".join(self.children())
        close = "</%s>" % name
        assert self.s.startswith(close, self.i), (name, self.s[self.i : self.i + 20])
        self.i += len(close)
        return "<%s%s>%s</%s>" % (tag, a, kids, tag)


def convert(src):
    icons = []
    pat = re.compile(
        r"export function (\w+)\(\{([^}]*)\}: \w+\) \{\n  return \(\n(.*?)\n  \);\n\}", re.S
    )
    for m in pat.finditer(src):
        name, params, body = m.groups()
        color = re.search(r"color = '(#[0-9A-Fa-f]{6})'", params).group(1)
        size = re.search(r"size = (\d+)", params).group(1)
        has_focused = "focused" in params
        svg = re.search(r"<Svg ([^>]*)>(.*)</Svg>", body, re.S)
        viewbox = re.search(r'viewBox="([^"]+)"', svg.group(1)).group(1)
        inner = "".join(Parser(svg.group(2)).children())
        icons.append((name, color, size, has_focused, viewbox, inner))
    return icons


def emit(icons):
    out = [
        "// GENERATED by tool/gen_custom_icons.py from CustomIcons.tsx. Do not edit by hand.",
        "import 'package:flutter/material.dart';",
        "import 'package:flutter_svg/flutter_svg.dart';",
        "",
        "String _hex(Color color) =>",
        "    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';",
        "",
        "Widget _svg(String svg, double size) =>",
        "    SvgPicture.string(svg, width: size, height: size);",
        "",
    ]
    for name, color, size, focused, viewbox, inner in icons:
        fn = "_svg" + name
        out.append("String %s(String c, bool focused) =>" % fn)
        out.append(
            "    '''<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"%s\" fill=\"none\">%s</svg>''';"
            % (viewbox, inner.replace("\\", "\\\\"))
        )
        out.append("")
        out.append("/// Custom FitTrack Pro icon (port of `%s`)." % name)
        out.append("class %s extends StatelessWidget {" % name)
        if focused:
            out.append(
                "  const %s({this.size = %s, this.color = const Color(0xFF%s), this.focused = false, super.key});"
                % (name, size, color[1:].upper())
            )
        else:
            out.append(
                "  const %s({this.size = %s, this.color = const Color(0xFF%s), super.key});"
                % (name, size, color[1:].upper())
            )
        out.append("  final double size;")
        out.append("  final Color color;")
        if focused:
            out.append("  final bool focused;")
        out.append("")
        out.append("  @override")
        out.append(
            "  Widget build(BuildContext context) => _svg(%s(_hex(color), %s), size);"
            % (fn, "focused" if focused else "false")
        )
        out.append("}")
        out.append("")
    out.append("/// One instance of every icon, for galleries and render tests.")
    out.append("List<Widget> buildAllCustomIcons(Color color, {required bool focused}) => [")
    for name, _color, _size, has_focused, _vb, _inner in icons:
        if has_focused:
            out.append("      %s(color: color, focused: focused)," % name)
        else:
            out.append("      %s(color: color)," % name)
    out.append("    ];")
    out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    icons = convert(open(sys.argv[1]).read())
    open("lib/core/widgets/custom_icons.dart", "w").write(emit(icons))
    print(len(icons), "icons")
