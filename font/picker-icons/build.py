# /// script
# requires-python = ">=3.10"
# dependencies = ["fonttools==4.68.0", "skia-pathops==0.9.2"]
# ///
"""Build the companion font from the two simple SVG sources: uv run build.py."""

from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

import pathops
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import SVGPath


HERE = Path(__file__).resolve().parent
ICONS = {
    "worktree": (0xF5000, "worktree.svg"),
    "repo_branch": (0xF5001, "repo-branch.svg"),
}
CAPS = {
    "butt": pathops.LineCap.BUTT_CAP,
    "round": pathops.LineCap.ROUND_CAP,
    "square": pathops.LineCap.SQUARE_CAP,
}
JOINS = {
    "miter": pathops.LineJoin.MITER_JOIN,
    "round": pathops.LineJoin.ROUND_JOIN,
    "bevel": pathops.LineJoin.BEVEL_JOIN,
}


def read_outline(source):
    """Convert our flat SVG shapes, fills, and strokes to united font contours."""
    root = ET.parse(source).getroot()
    if root.get("viewBox") != "0 0 16 16":
        raise ValueError(f"{source}: expected a 16-unit viewBox")
    result = pathops.Path()
    for element in root:
        tag = element.tag.rsplit("}", 1)[-1]
        if tag == "title":
            continue
        if tag not in {"path", "circle", "rect"}:
            raise ValueError(f"{source}: unsupported SVG element {tag}")
        attrs = {**root.attrib, **element.attrib}
        wrapper = ET.Element("{http://www.w3.org/2000/svg}svg")
        wrapper.append(deepcopy(element))
        shape = pathops.Path()
        SVGPath.fromstring(ET.tostring(wrapper)).draw(shape.getPen())
        parts = []
        if attrs.get("fill", "black") != "none":
            filled = pathops.Path(shape)
            if attrs.get("fill-rule") == "evenodd":
                filled.fillType = pathops.FillType.EVEN_ODD
            parts.append(pathops.simplify(filled))
        if attrs.get("stroke", "none") != "none":
            stroked = pathops.Path(shape)
            stroked.stroke(
                float(attrs.get("stroke-width", "1")),
                CAPS[attrs.get("stroke-linecap", "butt")],
                JOINS[attrs.get("stroke-linejoin", "miter")],
                float(attrs.get("stroke-miterlimit", "4")),
            )
            stroked.convertConicsToQuads(0.001)
            parts.append(pathops.simplify(stroked))
        for part in parts:
            result = pathops.op(result, part, pathops.PathOp.UNION)
    return result


def build_font():
    glyphs = {name: TTGlyphPen(None).glyph() for name in (".notdef", "space")}
    for name, (_, filename) in ICONS.items():
        pen = TTGlyphPen(None)
        # A square symbol with breathing room; Ghostty can use the following
        # space for a private-use glyph. Zsh reserves two spaces after it.
        read_outline(HERE / filename).draw(
            TransformPen(Cu2QuPen(pen, max_err=1.0), (56.25, 0, 0, -56.25, 50, 800))
        )
        glyphs[name] = pen.glyph()

    font = FontBuilder(1000, isTTF=True)
    font.setupGlyphOrder(list(glyphs))
    font.setupCharacterMap({0x20: "space", **{cp: name for name, (cp, _) in ICONS.items()}})
    font.setupGlyf(glyphs)
    font.setupHorizontalMetrics({
        name: (1000, glyph.xMin if glyph.numberOfContours else 0)
        for name, glyph in glyphs.items()
    })
    font.setupHorizontalHeader(ascent=900, descent=-100)
    font.setupNameTable({
        "familyName": "Picker Icons",
        "styleName": "Regular",
        "uniqueFontIdentifier": "PickerIcons-Regular-1.0",
        "fullName": "Picker Icons Regular",
        "psName": "PickerIcons-Regular",
        "version": "Version 1.0",
    })
    font.setupOS2(
        version=4,
        sTypoAscender=900, sTypoDescender=-100, sTypoLineGap=0,
        usWinAscent=900, usWinDescent=100, sxHeight=500, sCapHeight=800,
        fsSelection=0xC0,
    )
    font.setupPost(isFixedPitch=1)
    font.setupMaxp()
    font.font["head"].created = font.font["head"].modified = 2082844800
    font.font.recalcTimestamp = False
    output = HERE / "PickerIcons.ttf"
    font.save(output)
    print(f"Built {output}")


if __name__ == "__main__":
    build_font()
