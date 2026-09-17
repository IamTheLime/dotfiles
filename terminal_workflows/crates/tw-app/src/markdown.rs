//! Markdown for the sidebar: parsed once into blocks, rendered as gpui
//! elements. Fenced code is highlighted with syntect. Meant for LSP hover
//! text and small documents, not for a full CommonMark viewer.

use std::ops::Range;
use std::sync::LazyLock;

use gpui::{
    AnyElement, Font, FontStyle, FontWeight, HighlightStyle, Hsla, InteractiveText, Rgba, SharedString, StyledText,
    TextRun, TextStyle, UnderlineStyle, div, font, prelude::*, px,
};
use pulldown_cmark::{CodeBlockKind, Event, HeadingLevel, Options, Parser, Tag, TagEnd};
use syntect::easy::HighlightLines;
use syntect::highlighting::{FontStyle as SyntectFontStyle, Theme, ThemeSet};
use syntect::parsing::SyntaxSet;
use syntect::util::LinesWithEndings;

use crate::theme;

#[derive(Clone, Debug, PartialEq)]
pub struct Document {
    pub title: String,
    pub blocks: Vec<Block>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Block {
    Heading { level: u8, spans: Vec<Span> },
    Paragraph(Vec<Span>),
    Code { lang: Option<String>, lines: Vec<Vec<CodeSpan>> },
    List { ordered: bool, items: Vec<Vec<Span>> },
    Quote(Vec<Span>),
    Rule,
}

/// A run of inline text with the styling that applies to all of it.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Span {
    pub text: String,
    pub bold: bool,
    pub italic: bool,
    pub code: bool,
    pub link: Option<String>,
}

/// A run of highlighted code; colours come from syntect's theme.
#[derive(Clone, Debug, PartialEq)]
pub struct CodeSpan {
    pub text: String,
    pub color: Hsla,
    pub bold: bool,
    pub italic: bool,
}

impl Document {
    pub fn new(title: impl Into<String>, markdown: &str) -> Self {
        Self { title: title.into(), blocks: parse(markdown) }
    }
}

// --- parsing ---------------------------------------------------------------------

#[derive(Clone, Default)]
struct InlineStyle {
    bold: bool,
    italic: bool,
    link: Option<String>,
}

/// Where inline text is going. pulldown-cmark nests these, so a small stack
/// of flags is enough to know what to emit when a container ends.
struct Builder {
    blocks: Vec<Block>,
    spans: Vec<Span>,
    style: InlineStyle,
    heading: Option<u8>,
    quote_depth: usize,
    lists: Vec<ListBuilder>,
    code: Option<CodeBuilder>,
    in_table_row: bool,
}

struct ListBuilder {
    ordered: bool,
    items: Vec<Vec<Span>>,
}

struct CodeBuilder {
    lang: Option<String>,
    text: String,
}

pub fn parse(markdown: &str) -> Vec<Block> {
    let mut b = Builder {
        blocks: Vec::new(),
        spans: Vec::new(),
        style: InlineStyle::default(),
        heading: None,
        quote_depth: 0,
        lists: Vec::new(),
        code: None,
        in_table_row: false,
    };
    let options = Options::ENABLE_STRIKETHROUGH | Options::ENABLE_TABLES | Options::ENABLE_TASKLISTS;
    for event in Parser::new_ext(markdown, options) {
        b.event(event);
    }
    b.flush_paragraph();
    b.blocks
}

impl Builder {
    fn event(&mut self, event: Event<'_>) {
        if let Some(code) = &mut self.code {
            // Everything inside a fence is literal until it closes.
            match event {
                Event::Text(text) => code.text.push_str(&text),
                Event::End(TagEnd::CodeBlock) => {
                    let CodeBuilder { lang, text } = self.code.take().expect("checked above");
                    self.blocks.push(Block::Code { lang: lang.clone(), lines: highlight(&text, lang.as_deref()) });
                }
                _ => {}
            }
            return;
        }
        match event {
            Event::Start(tag) => self.start(tag),
            Event::End(tag) => self.end(tag),
            Event::Text(text) => self.push_text(&text),
            Event::Code(text) => self.spans.push(Span { text: text.into_string(), code: true, ..self.span_style() }),
            Event::SoftBreak => self.push_text(" "),
            Event::HardBreak => self.push_text("\n"),
            Event::Rule => {
                self.flush_paragraph();
                self.blocks.push(Block::Rule);
            }
            Event::TaskListMarker(checked) => self.push_text(if checked { "[x] " } else { "[ ] " }),
            Event::Html(html) | Event::InlineHtml(html) => self.push_text(&html),
            Event::InlineMath(text) | Event::DisplayMath(text) => self.push_text(&text),
            Event::FootnoteReference(name) => self.push_text(&format!("[{name}]")),
        }
    }

    fn start(&mut self, tag: Tag<'_>) {
        match tag {
            Tag::Heading { level, .. } => {
                self.flush_paragraph();
                self.heading = Some(heading_level(level));
            }
            Tag::Paragraph => self.flush_paragraph(),
            Tag::CodeBlock(kind) => {
                self.flush_paragraph();
                let lang = match kind {
                    CodeBlockKind::Fenced(info) => info.split_whitespace().next().map(str::to_owned).filter(|s| !s.is_empty()),
                    CodeBlockKind::Indented => None,
                };
                self.code = Some(CodeBuilder { lang, text: String::new() });
            }
            Tag::List(first) => {
                self.flush_paragraph();
                self.lists.push(ListBuilder { ordered: first.is_some(), items: Vec::new() });
            }
            Tag::Item => self.flush_paragraph(),
            Tag::BlockQuote(_) => {
                self.flush_paragraph();
                self.quote_depth += 1;
            }
            Tag::Emphasis => self.style.italic = true,
            Tag::Strong => self.style.bold = true,
            Tag::Link { dest_url, .. } => self.style.link = Some(dest_url.into_string()),
            Tag::Image { dest_url, .. } => self.push_text(&format!("[image: {dest_url}]")),
            Tag::TableRow | Tag::TableHead => {
                self.flush_paragraph();
                self.in_table_row = true;
            }
            Tag::TableCell if self.in_table_row && !self.spans.is_empty() => self.push_text("  ·  "),
            Tag::TableCell => {}
            // Strikethrough, tables themselves, footnotes, metadata: content still flows as text.
            _ => {}
        }
    }

    fn end(&mut self, tag: TagEnd) {
        match tag {
            TagEnd::Heading(_) => {
                let spans = std::mem::take(&mut self.spans);
                let level = self.heading.take().unwrap_or(1);
                self.blocks.push(Block::Heading { level, spans });
            }
            TagEnd::Paragraph => self.flush_paragraph(),
            TagEnd::Item => {
                let spans = std::mem::take(&mut self.spans);
                let depth = self.lists.len().saturating_sub(1);
                if let Some(list) = self.lists.last_mut() {
                    let mut item = spans;
                    if depth > 0 {
                        item.insert(0, Span { text: "  ".repeat(depth), ..Span::default() });
                    }
                    list.items.push(item);
                }
            }
            TagEnd::List(_) => {
                if let Some(ListBuilder { ordered, items }) = self.lists.pop() {
                    match self.lists.last_mut() {
                        // Nested list: fold its items into the parent so one block holds them all.
                        Some(parent) => parent.items.extend(items),
                        None => self.blocks.push(Block::List { ordered, items }),
                    }
                }
            }
            TagEnd::BlockQuote(_) => {
                self.flush_paragraph();
                self.quote_depth = self.quote_depth.saturating_sub(1);
            }
            TagEnd::Emphasis => self.style.italic = false,
            TagEnd::Strong => self.style.bold = false,
            TagEnd::Link => self.style.link = None,
            TagEnd::TableRow | TagEnd::TableHead => {
                self.in_table_row = false;
                self.flush_paragraph();
            }
            _ => {}
        }
    }

    fn span_style(&self) -> Span {
        Span { bold: self.style.bold, italic: self.style.italic, link: self.style.link.clone(), ..Span::default() }
    }

    fn push_text(&mut self, text: &str) {
        let style = self.span_style();
        match self.spans.last_mut() {
            Some(last) if !last.code && last.bold == style.bold && last.italic == style.italic && last.link == style.link => {
                last.text.push_str(text);
            }
            _ => self.spans.push(Span { text: text.to_owned(), ..style }),
        }
    }

    fn flush_paragraph(&mut self) {
        if self.spans.is_empty() || self.heading.is_some() || !self.lists.is_empty() {
            return;
        }
        let spans = std::mem::take(&mut self.spans);
        if spans.iter().all(|s| s.text.trim().is_empty()) {
            return;
        }
        self.blocks.push(if self.quote_depth > 0 { Block::Quote(spans) } else { Block::Paragraph(spans) });
    }
}

fn heading_level(level: HeadingLevel) -> u8 {
    match level {
        HeadingLevel::H1 => 1,
        HeadingLevel::H2 => 2,
        HeadingLevel::H3 => 3,
        HeadingLevel::H4 => 4,
        HeadingLevel::H5 => 5,
        HeadingLevel::H6 => 6,
    }
}

// --- code highlighting -----------------------------------------------------------

struct Highlighter {
    syntaxes: SyntaxSet,
    theme: Theme,
}

static HIGHLIGHTER: LazyLock<Highlighter> = LazyLock::new(|| {
    let mut themes = ThemeSet::load_defaults();
    Highlighter {
        syntaxes: SyntaxSet::load_defaults_newlines(),
        theme: themes.themes.remove("base16-ocean.dark").expect("syntect bundles base16-ocean.dark"),
    }
});

fn highlight(code: &str, lang: Option<&str>) -> Vec<Vec<CodeSpan>> {
    let h = &*HIGHLIGHTER;
    let syntax = lang
        .and_then(|token| h.syntaxes.find_syntax_by_token(token))
        .unwrap_or_else(|| h.syntaxes.find_syntax_plain_text());
    let mut lines = HighlightLines::new(syntax, &h.theme);
    LinesWithEndings::from(code)
        .map(|line| {
            lines
                .highlight_line(line, &h.syntaxes)
                .unwrap_or_default()
                .into_iter()
                .map(|(style, text)| CodeSpan {
                    text: text.trim_end_matches(['\n', '\r']).replace('\t', "    "),
                    color: syntect_color(style.foreground),
                    bold: style.font_style.contains(SyntectFontStyle::BOLD),
                    italic: style.font_style.contains(SyntectFontStyle::ITALIC),
                })
                .filter(|span| !span.text.is_empty())
                .collect()
        })
        .collect()
}

fn syntect_color(color: syntect::highlighting::Color) -> Hsla {
    Rgba { r: f32::from(color.r) / 255.0, g: f32::from(color.g) / 255.0, b: f32::from(color.b) / 255.0, a: 1.0 }.into()
}

// --- rendering -------------------------------------------------------------------

/// `base` is the surrounding text style (usually `window.text_style()`), so
/// inline runs inherit the UI font and size.
pub fn render(document: &Document, base: &TextStyle) -> impl IntoElement {
    let blocks = document.blocks.iter().enumerate().map(|(index, block)| render_block(index, block, base));
    div().flex().flex_col().gap_2().children(blocks)
}

fn render_block(index: usize, block: &Block, base: &TextStyle) -> AnyElement {
    match block {
        Block::Heading { level, spans } => div()
            .pt_1()
            .text_size(px(match level {
                1 => 17.0,
                2 => 15.0,
                _ => 14.0,
            }))
            .font_weight(FontWeight::BOLD)
            .child(rich_text(index, spans, base))
            .into_any_element(),
        Block::Paragraph(spans) => div().text_sm().child(rich_text(index, spans, base)).into_any_element(),
        Block::Quote(spans) => div()
            .pl_2()
            .border_l_2()
            .border_color(theme::accent())
            .text_sm()
            .text_color(theme::muted())
            .child(rich_text(index, spans, base))
            .into_any_element(),
        Block::List { ordered, items } => div()
            .flex()
            .flex_col()
            .gap_1()
            .text_sm()
            .children(items.iter().enumerate().map(|(n, spans)| {
                let marker = if *ordered { format!("{}.", n + 1) } else { "•".to_owned() };
                div()
                    .flex()
                    .gap_2()
                    .child(div().text_color(theme::muted()).child(marker))
                    .child(div().flex_1().min_w_0().child(rich_text(index * 1000 + n, spans, base)))
            }))
            .into_any_element(),
        Block::Code { lang, lines } => div()
            .flex()
            .flex_col()
            .rounded_md()
            .bg(theme::code_bg())
            .p_2()
            .children(lang.as_ref().map(|lang| div().text_xs().text_color(theme::muted()).pb_1().child(lang.clone())))
            .children(lines.iter().map(code_line))
            .into_any_element(),
        Block::Rule => div().h(px(1.0)).w_full().bg(theme::border()).into_any_element(),
    }
}

/// Inline spans as one text element; links open in the browser.
fn rich_text(id: usize, spans: &[Span], base: &TextStyle) -> AnyElement {
    let mut text = String::new();
    let mut highlights: Vec<(Range<usize>, HighlightStyle)> = Vec::new();
    let mut links: Vec<(Range<usize>, String)> = Vec::new();
    for span in spans {
        let start = text.len();
        text.push_str(&span.text);
        let range = start..text.len();
        let mut style = HighlightStyle::default();
        let mut styled = false;
        if span.bold {
            style.font_weight = Some(FontWeight::BOLD);
            styled = true;
        }
        if span.italic {
            style.font_style = Some(FontStyle::Italic);
            styled = true;
        }
        if span.code {
            style.background_color = Some(theme::code_bg());
            style.color = Some(theme::warn());
            styled = true;
        }
        if let Some(url) = &span.link {
            style.color = Some(theme::accent());
            style.underline = Some(UnderlineStyle { thickness: px(1.0), color: Some(theme::accent()), wavy: false });
            links.push((range.clone(), url.clone()));
            styled = true;
        }
        if styled {
            highlights.push((range, style));
        }
    }
    let styled = StyledText::new(SharedString::from(text)).with_default_highlights(base, highlights);
    if links.is_empty() {
        return styled.into_any_element();
    }
    let urls: Vec<String> = links.iter().map(|(_, url)| url.clone()).collect();
    InteractiveText::new(("markdown-link", id), styled)
        .on_click(links.into_iter().map(|(range, _)| range).collect(), move |index, _, cx| {
            if let Some(url) = urls.get(index) {
                cx.open_url(url);
            }
        })
        .into_any_element()
}

fn code_line(spans: &Vec<CodeSpan>) -> AnyElement {
    let mono: Font = font(theme::FONT_FAMILY);
    let mut text = String::new();
    let mut runs = Vec::with_capacity(spans.len());
    for span in spans {
        text.push_str(&span.text);
        runs.push(TextRun {
            len: span.text.len(),
            font: Font {
                weight: if span.bold { FontWeight::BOLD } else { FontWeight::NORMAL },
                style: if span.italic { FontStyle::Italic } else { FontStyle::Normal },
                ..mono.clone()
            },
            color: span.color,
            background_color: None,
            underline: None,
            strikethrough: None,
        });
    }
    if text.is_empty() {
        text.push(' ');
        runs.push(TextRun { len: 1, font: mono, color: theme::text(), background_color: None, underline: None, strikethrough: None });
    }
    div().text_xs().whitespace_nowrap().child(StyledText::new(SharedString::from(text)).with_runs(runs)).into_any_element()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_parse_hover_style_markdown_into_blocks() {
        let blocks = parse("```rust\nfn main() {}\n```\n\n---\n\n# Title\n\nSome **bold** and `code` text.\n\n- one\n- two\n\n> quoted");
        assert!(matches!(&blocks[0], Block::Code { lang: Some(lang), lines } if lang == "rust" && lines.len() == 1));
        assert_eq!(blocks[1], Block::Rule);
        assert!(matches!(&blocks[2], Block::Heading { level: 1, spans } if spans[0].text == "Title"));
        let Block::Paragraph(spans) = &blocks[3] else { panic!("expected a paragraph, got {:?}", blocks[3]) };
        assert_eq!(spans.iter().map(|s| (s.text.as_str(), s.bold, s.code)).collect::<Vec<_>>(), vec![
            ("Some ", false, false),
            ("bold", true, false),
            (" and ", false, false),
            ("code", false, true),
            (" text.", false, false),
        ]);
        assert!(matches!(&blocks[4], Block::List { ordered: false, items } if items.len() == 2));
        assert!(matches!(&blocks[5], Block::Quote(spans) if spans[0].text == "quoted"));
    }

    #[test]
    fn should_keep_code_lines_aligned_and_coloured() {
        let Block::Code { lines, .. } = &parse("```rust\nlet x = 1;\n\n\tdone\n```")[0] else { panic!("expected code") };
        assert_eq!(lines.len(), 3);
        let first: String = lines[0].iter().map(|s| s.text.as_str()).collect();
        assert_eq!(first, "let x = 1;");
        assert!(lines[0].len() > 1, "a keyword and a literal should be separate coloured runs");
        assert!(lines[1].is_empty());
        assert_eq!(lines[2].iter().map(|s| s.text.as_str()).collect::<String>(), "    done");
    }

    #[test]
    fn should_treat_unknown_languages_as_plain_text() {
        let Block::Code { lang, lines } = &parse("```zzz-not-a-language\nhello\n```")[0] else { panic!("expected code") };
        assert_eq!(lang.as_deref(), Some("zzz-not-a-language"));
        assert_eq!(lines[0].iter().map(|s| s.text.as_str()).collect::<String>(), "hello");
    }
}
