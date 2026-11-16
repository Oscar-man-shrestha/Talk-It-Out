"""Builds docs/Talk-It-Out-Guide.pdf: the product and technical guide for
new users and teammates. Run: python3 tool/make_guide.py (needs reportlab).
Keep it in step with API.md, LOGS.md and the code when features change.
"""
import os

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate, Frame, KeepTogether, NextPageTemplate, PageBreak, PageTemplate,
    Paragraph, Spacer, Table, TableStyle,
)
from reportlab.platypus.tableofcontents import TableOfContents

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "docs", "Talk-It-Out-Guide.pdf")

INK = colors.HexColor("#09090B")
SOFT = colors.HexColor("#52525B")
FAINT = colors.HexColor("#A1A1AA")
BORDER = colors.HexColor("#E4E4E7")
TINT = colors.HexColor("#F4F4F5")
PAPER = colors.HexColor("#FAFAFA")
WHITE = colors.white

VERSION = "Version 1.0 · 16 November 2026 · branch temp/project-completion-run070"

# ------------------------------------------------------------------ styles
base = ParagraphStyle("base", fontName="Helvetica", fontSize=9.6, leading=14.2, textColor=INK, alignment=TA_LEFT)
S = {
    "body": base,
    "small": ParagraphStyle("small", parent=base, fontSize=8.4, leading=11.8, textColor=SOFT),
    "cell": ParagraphStyle("cell", parent=base, fontSize=8.6, leading=11.8),
    "cellb": ParagraphStyle("cellb", parent=base, fontSize=8.6, leading=11.8, fontName="Helvetica-Bold"),
    "head": ParagraphStyle("head", parent=base, fontSize=8.2, leading=11, fontName="Helvetica-Bold", textColor=WHITE),
    "h1": ParagraphStyle("h1", parent=base, fontName="Helvetica-Bold", fontSize=20, leading=25, spaceAfter=4),
    "h2": ParagraphStyle("h2", parent=base, fontName="Helvetica-Bold", fontSize=13, leading=17, spaceBefore=12, spaceAfter=4),
    "h3": ParagraphStyle("h3", parent=base, fontName="Helvetica-Bold", fontSize=10.6, leading=14, spaceBefore=8, spaceAfter=2),
    "lead": ParagraphStyle("lead", parent=base, fontSize=11, leading=16, textColor=SOFT, spaceAfter=8),
    "bullet": ParagraphStyle("bullet", parent=base, leftIndent=12, bulletIndent=2, spaceAfter=2),
    "callout": ParagraphStyle("callout", parent=base, fontSize=9.4, leading=13.6),
    "toc1": ParagraphStyle("toc1", parent=base, fontSize=10, leading=13, spaceBefore=3.5, fontName="Helvetica-Bold"),
    "toc2": ParagraphStyle("toc2", parent=base, fontSize=8.6, leading=10.8, leftIndent=14, textColor=SOFT),
}


def P(text, style="body"):
    return Paragraph(text, S[style])


def H1(text):
    p = Paragraph(text, S["h1"])
    p.toc_level = 0
    return p


def H2(text):
    p = Paragraph(text, S["h2"])
    p.toc_level = 1
    return p


def H2n(text):
    """A section heading that is not listed in the contents."""
    return Paragraph(text, S["h2"])


def H3(text):
    return Paragraph(text, S["h3"])


def bullets(items):
    return [Paragraph(i, S["bullet"], bulletText="•") for i in items]


def table(rows, widths, header=True, zebra=True):
    data = []
    for r, row in enumerate(rows):
        out = []
        for c, cell in enumerate(row):
            if isinstance(cell, str):
                style = "head" if header and r == 0 else ("cellb" if c == 0 else "cell")
                out.append(Paragraph(cell, S[style]))
            else:
                out.append(cell)
        data.append(out)
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    cmds = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4.5),
        ("LINEBELOW", (0, 0), (-1, -1), 0.4, BORDER),
        ("BOX", (0, 0), (-1, -1), 0.6, BORDER),
    ]
    if header:
        cmds += [("BACKGROUND", (0, 0), (-1, 0), INK)]
    if zebra:
        for r in range(1 if header else 0, len(data)):
            if r % 2 == 0:
                cmds.append(("BACKGROUND", (0, r), (-1, r), PAPER))
    t.setStyle(TableStyle(cmds))
    return t


def callout(title, text):
    t = Table([[Paragraph(f"<b>{title}</b><br/>{text}", S["callout"])]], colWidths=[174 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), TINT),
        ("LINEBEFORE", (0, 0), (0, -1), 2.2, INK),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return t


# ---------------------------------------------------------------- diagrams
def _box(d, x, y, w, h, title, lines=(), dark=False):
    d.add(Rect(x, y, w, h, rx=5, ry=5, fillColor=INK if dark else WHITE, strokeColor=INK, strokeWidth=0.9))
    fg = WHITE if dark else INK
    d.add(String(x + w / 2, y + h - 13, title, fontName="Helvetica-Bold", fontSize=8.6, fillColor=fg, textAnchor="middle"))
    for i, line in enumerate(lines):
        d.add(String(x + w / 2, y + h - 25 - i * 10, line, fontName="Helvetica", fontSize=7, fillColor=FAINT if dark else SOFT, textAnchor="middle"))


def _arrow(d, x1, y1, x2, y2, label=None, both=False, dy=4):
    d.add(Line(x1, y1, x2, y2, strokeColor=INK, strokeWidth=0.8))

    def head(xa, ya, xb, yb):
        import math
        a = math.atan2(yb - ya, xb - xa)
        s = 5
        d.add(Polygon([xb, yb, xb - s * math.cos(a - 0.4), yb - s * math.sin(a - 0.4),
                       xb - s * math.cos(a + 0.4), yb - s * math.sin(a + 0.4)], fillColor=INK, strokeColor=INK, strokeWidth=0.1))
    head(x1, y1, x2, y2)
    if both:
        head(x2, y2, x1, y1)
    if label:
        d.add(String((x1 + x2) / 2, (y1 + y2) / 2 + dy, label, fontName="Helvetica", fontSize=6.6, fillColor=SOFT, textAnchor="middle"))


def architecture_diagram():
    w, h = 174 * mm, 88 * mm
    d = Drawing(w, h)
    d.add(Rect(0, 0, w, h, fillColor=PAPER, strokeColor=BORDER, strokeWidth=0.6))
    top = h - 12
    # Clients
    _box(d, 10, top - 50, 112, 50, "Flutter app", ["Android phone · web", "Riverpod · go_router · Dio"], dark=True)
    # API
    _box(d, 192, top - 58, 150, 58, "Express API (Node 20)", ["REST /api/v1 · SSE /events", "auth · groups · feed · people", "NLP module · legal pages"])
    _arrow(d, 122, top - 20, 192, top - 20, "HTTPS + JSON", both=True)
    _arrow(d, 192, top - 36, 122, top - 36, "live events (SSE)", dy=-10)
    # Postgres
    _box(d, 192, 10, 150, 78, "PostgreSQL 16", ["raw_messages (controller only)", "published_messages (group)",
                                                 "posts · comments · feed_events", "jobs outbox · NOTIFY triggers"])
    _arrow(d, 250, top - 58, 250, 88, both=True)
    d.add(String(246, (88 + top - 58) / 2 - 3, "SQL", fontName="Helvetica", fontSize=6.6, fillColor=SOFT, textAnchor="end"))
    _arrow(d, 300, 88, 300, top - 58)
    d.add(String(304, (88 + top - 58) / 2 - 3, "NOTIFY", fontName="Helvetica", fontSize=6.6, fillColor=SOFT))
    # Worker and model
    _box(d, 404, top - 58, 82, 58, "Rewrite worker", ["Python", "claims jobs over", "internal HTTP"])
    _arrow(d, 342, top - 26, 404, top - 26, "claim / result", both=True)
    _box(d, 404, 10, 82, 60, "Language model", ["Qwen2.5-3B", "via Ollama", "(self-hosted)"], dark=True)
    _arrow(d, 445, top - 58, 445, 70, both=True)
    d.add(String(441, (70 + top - 58) / 2 - 3, "prompt", fontName="Helvetica", fontSize=6.6, fillColor=SOFT, textAnchor="end"))
    # Side services
    _box(d, 10, 56, 112, 38, "Google Sign-In", ["ID token checked by API"])
    _box(d, 10, 10, 112, 38, "Gmail SMTP", ["password-reset codes"])
    _arrow(d, 122, 75, 192, 75)
    _arrow(d, 192, 29, 122, 29)
    return d


def lifecycle_diagram():
    w, h = 174 * mm, 50 * mm
    d = Drawing(w, h)
    d.add(Rect(0, 0, w, h, fillColor=PAPER, strokeColor=BORDER, strokeWidth=0.6))
    steps = [
        ("1  Write", ["contributor types,", "ticks Anonymous", "if they want"]),
        ("2  Queue", ["raw_messages row", "(pending) + a", "rewrite job"]),
        ("3  Rewrite", ["worker asks the", "model; checks and", "scores the result"]),
        ("4  Review", ["controller sees", "original + rewrite,", "Accept or Reject"]),
        ("5  Publish", ["approved text only;", "anonymous: no", "author stored"]),
    ]
    bw, gap = 80, 12
    x = 12
    by = h - 78
    for i, (title, lines) in enumerate(steps):
        _box(d, x, by, bw, 66, title, lines, dark=(i == 4))
        if i < len(steps) - 1:
            _arrow(d, x + bw, by + 33, x + bw + gap, by + 33)
        x += bw + gap
    notes = [
        "Reject: nothing is published; the sender gets a plain notification with no reason.",
        "The group only ever reads published_messages. Original wording and real senders of anonymous",
        "messages stay in raw_messages, which only the group's controller can query.",
        "My messages shows the sender each message's status (waiting, published, not published), never others' text.",
    ]
    for i, line in enumerate(notes):
        d.add(String(12, by - 16 - i * 11, line, fontName="Helvetica", fontSize=7.6, fillColor=SOFT))
    return d


# --------------------------------------------------------------- template
class GuideDoc(BaseDocTemplate):
    def __init__(self, path):
        super().__init__(path, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=20 * mm, bottomMargin=18 * mm,
                         title="Talk It Out: Product and Technical Guide", author="Talk It Out team",
                         subject="Features, architecture, privacy model and status")
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="f")
        self.addPageTemplates([
            PageTemplate("cover", frames=[frame], onPage=self._cover),
            PageTemplate("page", frames=[frame], onPage=self._page),
        ])

    def afterFlowable(self, flowable):
        level = getattr(flowable, "toc_level", None)
        if level is not None:
            text = flowable.getPlainText()
            key = f"h{self.seq.nextf('heading')}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=level, closed=level > 0)
            self.notify("TOCEntry", (level, text, self.page, key))

    def _cover(self, c, doc):
        w, h = A4
        c.saveState()
        c.setFillColor(INK)
        c.rect(0, h * 0.42, w, h * 0.58, stroke=0, fill=1)
        # Logo: two bubbles.
        c.setFillColor(colors.HexColor("#52525B"))
        c.roundRect(28 * mm, h - 62 * mm, 26 * mm, 17 * mm, 4 * mm, stroke=0, fill=1)
        c.setFillColor(WHITE)
        c.roundRect(18 * mm, h - 72 * mm, 26 * mm, 17 * mm, 4 * mm, stroke=0, fill=1)
        c.setFillColor(INK)
        for i in range(3):
            c.circle(24.5 * mm + i * 6.5 * mm, h - 63.5 * mm, 1.4 * mm, stroke=0, fill=1)
        c.setFillColor(WHITE)
        c.setFont("Helvetica-Bold", 34)
        c.drawString(18 * mm, h - 100 * mm, "Talk It Out")
        c.setFont("Helvetica", 15)
        c.setFillColor(colors.HexColor("#D4D4D8"))
        c.drawString(18 * mm, h - 111 * mm, "Product and technical guide")
        c.setFont("Helvetica", 10.5)
        c.setFillColor(colors.HexColor("#A1A1AA"))
        c.drawString(18 * mm, h - 128 * mm, "Say what matters at work, safely: anonymous when it needs to be,")
        c.drawString(18 * mm, h - 134 * mm, "rewritten calmly by AI, and reviewed before anyone sees it.")
        c.setFillColor(INK)
        c.setFont("Helvetica-Bold", 10)
        c.drawString(18 * mm, h * 0.42 - 16 * mm, "Who this is for")
        c.setFont("Helvetica", 9.6)
        c.setFillColor(SOFT)
        for i, line in enumerate([
            "New users who want to know everything the app can do,",
            "and teammates joining the project who need the architecture,",
            "the privacy model, how to run it and what is left to build.",
        ]):
            c.drawString(18 * mm, h * 0.42 - 23 * mm - i * 5.2 * mm, line)
        c.setFont("Helvetica", 8.4)
        c.setFillColor(FAINT)
        c.drawString(18 * mm, 18 * mm, VERSION)
        c.restoreState()

    def _page(self, c, doc):
        w, h = A4
        c.saveState()
        c.setStrokeColor(BORDER)
        c.setLineWidth(0.6)
        c.line(18 * mm, h - 13 * mm, w - 18 * mm, h - 13 * mm)
        c.setFont("Helvetica-Bold", 7.8)
        c.setFillColor(INK)
        c.drawString(18 * mm, h - 11 * mm, "TALK IT OUT")
        c.setFont("Helvetica", 7.8)
        c.setFillColor(FAINT)
        c.drawRightString(w - 18 * mm, h - 11 * mm, "Product and technical guide")
        c.line(18 * mm, 12 * mm, w - 18 * mm, 12 * mm)
        c.drawString(18 * mm, 8 * mm, "16 November 2026")
        c.drawRightString(w - 18 * mm, 8 * mm, f"Page {doc.page}")
        c.restoreState()


# ---------------------------------------------------------------- content
def story():
    s = [NextPageTemplate("page"), PageBreak()]

    toc = TableOfContents()
    toc.levelStyles = [S["toc1"], S["toc2"]]
    s += [P("Contents", "h1"), Spacer(1, 6), toc, PageBreak()]

    # 1 ------------------------------------------------------------------
    s += [H1("1. What Talk It Out is")]
    s += [P("Talk It Out is a mobile and web app for honest conversation at work. It has two halves that share one "
            "account: <b>groups</b>, where a team can raise difficult things safely, and a public <b>community feed</b>, "
            "where anyone can ask workplace questions and get answers.", "lead")]
    s += [H2("The problem")]
    s += bullets([
        "People hold back at work: feedback about a manager, a broken process, pay, burnout. Saying it with your name feels risky; saying it anonymously in most tools invites abuse.",
        "Even when people do speak, heated wording makes the point land badly and starts arguments.",
        "Teams have no safe middle ground between a public channel and a private complaint.",
    ])
    s += [H2("The answer: four safeguards on every group message")]
    s += [table([
        ["Safeguard", "What happens"],
        ["Anonymity when needed", "A member can tick <b>Anonymous message</b>. Other members see <i>Anonymous user</i>. The group's controller, who reviews messages, can see who sent it. This disclosure is shown next to the checkbox every time."],
        ["Calm wording", "An AI model rewrites each message in a calm, professional tone that keeps the meaning. The sender can preview the wording before sending, and a tone hint helps while typing."],
        ["Human review", "Nothing reaches the group until the controller has compared the original with the rewrite and pressed Accept. Reject publishes nothing and gives no reason."],
        ["Original stays private", "Other members only ever see the approved rewrite, never the original words."],
    ], [44 * mm, 130 * mm])]
    s += [H2("Product principles")]
    s += bullets([
        "<b>Honest about privacy.</b> The app never claims more anonymity than it gives: the controller can always see the sender.",
        "<b>Safety by design.</b> Review before publish, block, report, and hidden questions after repeated reports.",
        "<b>Language technology that explains itself.</b> Every ranked question says why it is shown; summaries never name anyone.",
        "<b>Your data, your choice.</b> Personalisation can be turned off, feed activity is deleted after 180 days, and accounts can be deleted in the app.",
    ])

    # 2 ------------------------------------------------------------------
    s += [PageBreak(), H1("2. A new user's first ten minutes")]
    s += [P("This is the path a new person takes, and the best way to understand the app.", "lead")]
    steps = [
        ["Step", "What the user sees and does"],
        ["1. Create an account", "<b>Create an account</b> on the sign-in screen: email and password, or <b>Sign in with Google</b>. They confirm they are 18 or over and can open the Terms and Privacy Policy from the form."],
        ["2. Welcome tour", "Four short pages explain anonymity, the AI rewrite, controller review and the community feed. The last page asks <i>Where do you want to start?</i>"],
        ["3a. Create a group", "They name the group by its agenda (for example <i>Sprint retro</i>) and become its <b>controller</b>."],
        ["3b. Join a group", "They open an invite link or scan a QR code a controller shared, see the group name, member count and how anonymity works, then press Join."],
        ["3c. Explore questions", "They pick at least three interests (for example Career growth, Pay and equity) and land on the <b>For You</b> feed."],
        ["4. Send a message", "In a group they write, optionally tick Anonymous, preview the AI wording, and send. The message waits for review."],
        ["5. Review (controllers)", "The controller opens the review queue, compares original and rewrite, and accepts or rejects."],
        ["6. See it published", "The approved rewrite appears in the chat for everyone instantly. The sender is notified either way."],
        ["7. Ask the community", "In Feed they ask a question with a title and topic. While typing they see suggested topics and <i>Already asked?</i> similar questions."],
    ]
    s += [table(steps, [38 * mm, 136 * mm])]
    s += [Spacer(1, 8), callout("Empty screens guide people too",
          "A person with no groups sees <i>Start your first safe space</i> with buttons to create a group, join with an invite link "
          "or explore questions. Empty Notifications and My messages screens explain what will appear there.")]

    # 3 ------------------------------------------------------------------
    s += [PageBreak(), H1("3. Roles and permissions")]
    s += [P("There are no app-wide administrators. Power is per group: the person who creates a group controls it.", "lead")]
    Y, N = "Yes", "No"
    s += [table([
        ["Action", "Contributor", "Controller", "Any signed-in user"],
        ["Read the group chat", Y, Y, "Only if a member"],
        ["Send a message (with name or anonymously)", Y, "Posts announcements directly", N],
        ["See who sent an anonymous message", N, Y, N],
        ["See a member's original wording", "Only their own", Y, N],
        ["Review queue: accept, reject, ask for a new rewrite", N, Y, N],
        ["Pin messages, post polls, delete published messages", N, Y, N],
        ["Add members, make invite links, show QR codes", N, Y, N],
        ["Leave the group", Y, "Yes (hands control to the earliest member)", N],
        ["Ask questions, comment, like, report in the feed", Y, Y, Y],
        ["Block people, report questions, delete own account", Y, Y, Y],
    ], [70 * mm, 30 * mm, 40 * mm, 34 * mm])]
    s += [Spacer(1, 6), P("Controller-only screens are guarded in the app (non-controllers are redirected) and every controller "
                          "action is checked again by the server.", "small")]

    # 4 ------------------------------------------------------------------
    s += [PageBreak(), H1("4. Features in detail")]

    s += [H2("4.1 Accounts, sign-in and security")]
    s += bullets([
        "Register and sign in with email and password, or <b>Sign in with Google</b>. Passwords are stored as Argon2 hashes.",
        "<b>Keep active session</b>: a rotating refresh token keeps you signed in; tokens live only in the phone's secure storage.",
        "<b>Continue as</b>: after signing out, the sign-in screen offers the accounts used on this device (name and a masked email, never a password). Choosing one fills the email; the password is always typed. Accounts can be removed from the device.",
        "<b>Forgot password</b>: a 6-digit code is emailed (Gmail SMTP) and checked before a new password is set.",
        "<b>Change password</b> and <b>Sign out of all devices</b>: every token carries a version, so ending sessions works everywhere at once.",
        "<b>Delete account</b> (password-confirmed): your data is removed; groups you controlled are handed over; your published group messages stay but become anonymous.",
        "Legal pages (Privacy Policy, Terms of Use, How deletion works) are readable in the app, even before signing in.",
    ])

    s += [H2("4.2 Groups and membership")]
    s += bullets([
        "<b>Create a group</b> around an agenda; the creator is its controller. The groups list shows each group's latest message, unread count and how many messages wait for review.",
        "<b>Add members, like Instagram</b>: search as you type. Search forgives typos and sound-alike spellings (<i>rhoan</i> finds Rohan), puts people from your groups first, suggests people and remembers recent picks. Pick several and add them at once.",
        "<b>Invite links and QR codes</b>: a controller creates a link that lasts 1, 7 or 30 days or never expires, optionally for a set number of people, then shares it through WhatsApp or any app, copies it, or shows a QR code. Links can be turned off.",
        "<b>Join screen</b>: anyone opening a link sees the group, the inviter and how anonymity works before joining. A link can also be pasted on the empty Groups screen.",
        "<b>Group info</b>: a description and rules set by the controller, plus your own <b>Mute</b> (out of the badge) and <b>Pin to top</b>.",
        "<b>Leave a group</b>: a departing controller hands control to the earliest-joined member.",
    ])

    s += [H2("4.3 Group chat")]
    s += [table([
        ["Feature", "Details"],
        ["Anonymous messages", "Checkbox just before Send, with the disclosure: anonymous messages are hidden from the group but visible to the controller."],
        ["AI rewrite and preview", "Every message is rewritten in your chosen tone (professional, direct, Socratic or empathetic; anonymous messages always use the default). <b>Preview AI wording</b> shows the rewrite before sending."],
        ["Tone hint", "While typing, an on-device check gently flags insults, blame, <i>always/never</i> about people and shouting. It never blocks sending and nothing is sent anywhere for it."],
        ["Catch up", "A summary of the recent conversation: key points, open questions and main topics. Built from approved messages only; it never names anyone."],
        ["Replies, withdraw, search", "Reply to a message (tap the quote to jump to it), withdraw your own message before it is reviewed, search the group, load earlier messages."],
        ["Photos", "Attach a photo; the server strips location and camera details. The controller sees it in review; the group sees it only after approval."],
        ["Reactions", "Six quick reactions plus any emoji. Only counts are shown, never who reacted."],
        ["Pins and polls", "Controllers pin important messages and post polls. Votes are counted, never shown by person."],
        ["Chat polish", "Bubbles, date dividers, a <i>New messages</i> divider, swipe to reply, @mention suggestions, drafts kept per chat, big emoji-only messages, a full emoji keyboard, jump-to-latest."],
        ["My messages", "Each of your messages with its status: waiting, published or not published. Only you see this list; it never shows a rejection reason."],
    ], [38 * mm, 136 * mm])]

    s += [H2("4.4 Controller review")]
    s += bullets([
        "<b>Review queue</b>: the original and the AI rewrite side by side with a word-level difference, plus advisory scores for how well meaning was kept and how relevant the message is to the agenda.",
        "Sort by age, relevance or readiness. Relevance is advisory: it labels messages but never hides or rejects them.",
        "<b>Accept</b> publishes the rewrite. <b>Reject</b> publishes nothing and sends a neutral notification with no reason. <b>New rewrite</b> asks the AI again.",
        "Approved and Rejected tabs keep a read-only history of decisions.",
        "<b>Announcements</b>: controllers can post directly without review, and delete published messages.",
    ])

    s += [H2("4.5 Community feed (questions and answers)")]
    s += [table([
        ["Feature", "Details"],
        ["Ask a question", "Title, one of six topics and details. Your name is always shown: the feed is never anonymous. Topic suggestions and <i>Already asked?</i> similar questions appear while you type."],
        ["For You", "Ranked for you from interests you picked and ones learned from what you like, answer and open. Every question says why it is shown. <b>Not interested</b> hides it, with Undo."],
        ["Latest", "Newest first with topic and status filters, sort by newest, likes or discussion, and endless scrolling."],
        ["Search", "Understands word families and typos and offers <i>Showing results for</i> corrections."],
        ["Best answers", "Upvote helpful answers; the asker marks a <b>best answer</b>, shown first. Follow a question to hear about new answers. Questions and answers can be edited and show <i>edited</i>."],
        ["Answers and likes", "Comments with mentions and reports; a question's author sees report counts and can remove comments. <b>Liked by</b> shows who liked a question, like Facebook (group chat reactions stay counts only)."],
        ["Interests", "30 interests, from Engineering and Pay to Mental health, Rights at work and Students, each with its own icon. Pick them on first visit and change them in Profile."],
        ["Share and save", "Share a question through any app; save questions on your device."],
        ["Question to group", "A question's author can turn it into a group to discuss it privately."],
        ["Safety", "Report a question (six reasons); five reports from different people hide it from everyone except its author."],
    ], [38 * mm, 136 * mm])]

    s += [H2("4.6 People and profiles")]
    s += bullets([
        "<b>Your profile</b>: name, headline, bio, location, links, skills, experience, education, photo and cover, a public <b>@handle</b> (with live availability check), feed interests and the personalisation switch.",
        "<b>Other people's profiles</b>: tap any name or photo in the feed, comments, members list or named chat messages. Shows their headline, shared groups, questions and an <b>Add to group</b> button.",
        "<b>Block</b>: you and they disappear from each other's search, feed, comments and profiles, and cannot add each other to groups. Groups you already share are unchanged. Profile -> Blocked people lists them with Unblock.",
        "<b>Invite friends</b>: share the app from Profile.",
    ])

    s += [KeepTogether([H2("4.7 Notifications and live updates")] + bullets([
        "Alerts when a message waits for your review or was not published, when someone answers a question you follow, when your answer is marked best, and when you are @mentioned in a group (never naming the sender). Filters for submissions, moderation and community, and mark-all-read.",
        "Live updates: new messages, reviews, members, reactions and alerts appear instantly, like a messaging app, and the app re-syncs after a connection gap.",
    ]))]
    s += [KeepTogether([H2("4.8 Onboarding, sharing and help")] + bullets([
        "<b>Welcome tour</b> for brand-new accounts: four pages on anonymity, the AI rewrite, review and the community, then <i>create a group, join with a link or explore questions</i>. Shown once; people signing in again never see it.",
        "<b>Helpful empty screens</b> explain each place and offer the next step instead of a blank page.",
        "<b>Share</b> questions and invite links through WhatsApp, Telegram, email or any app on the phone, or copy them.",
        "<b>Legal and help</b>: Privacy Policy, Terms of Use and How deletion works, from Register and Profile.",
        "<b>Demo mode</b>: the whole app runs with built-in sample data and no server, for showing it to anyone.",
    ]))]

    # 5 ------------------------------------------------------------------
    s += [PageBreak(), H1("5. Language technology (NLP and AI)")]
    s += [P("Talk It Out uses language technology wherever it helps people, and keeps it explainable and private. "
            "Only the message rewrite uses a large language model; everything else is fast, transparent classic NLP that runs on our "
            "own server or on the phone.", "lead")]
    s += [table([
        ["Feature", "Technique", "Runs on"],
        ["Message rewrite", "Qwen2.5-3B-Instruct (self-hosted with Ollama), kept loaded so a rewrite takes about 2 s. Prompt-injection defence, deterministic output checks, meaning-kept and relevance scores.", "Python worker + model server"],
        ["People search", "Accent folding, Damerau-Levenshtein distance (swapped letters), Jaro-Winkler, phonetic keys for English and South Asian names, trigram indexes.", "Server + Postgres"],
        ["Topic suggestions and interests", "Lexicon classifier over 30 interests with stemming; every interest is checked against real questions in tests.", "Server"],
        ["For You ranking", "Interest match, TF-IDF similarity to what you engaged with, engagement with time decay, network bonus, freshness; then topic and author diversity and an exploration slot. Every result carries a reason.", "Server"],
        ["Feed search", "BM25 ranking over titles (counted twice) and bodies, light stemming, typo and prefix expansion, <i>did you mean</i>.", "Server"],
        ["Already asked?", "The draft's rarest words (by IDF) scored with BM25 and normalised; similar questions above a threshold.", "Server"],
        ["Catch up", "Extractive TextRank: PageRank over TF-IDF sentence similarity; highlights in the order said, open questions, key topics and themes. No names.", "Server"],
        ["Tone hint", "Lexicon and patterns for insults, blame, absolutes about people and shouting. Never blocks; nothing leaves the phone.", "Phone"],
        ["Feed content checks", "A separate feed-analysis worker flags content through a versioned internal contract.", "Server worker"],
    ], [34 * mm, 104 * mm, 36 * mm])]
    s += [Spacer(1, 8), callout("Why not a large model for everything?",
          "Classic methods are instant, cost nothing per request, run without sending text to anyone and can explain their "
          "results (\"Because you follow Career growth\"). The roadmap adds embeddings for meaning-based search where they clearly help.")]

    # 6 ------------------------------------------------------------------
    s += [PageBreak(), H1("6. Privacy and safety model")]
    s += [H2("Anonymity is enforced by the data model")]
    s += bullets([
        "<b>Two tables.</b> <font face='Courier'>raw_messages</font> holds the original text and real sender and is readable only by the group's controller. "
        "<font face='Courier'>published_messages</font> holds only approved text; for an anonymous message its author is stored as empty (a database check enforces this).",
        "Group screens in the app use a model that has no original-text field and no real-sender field; a test fails the build if review code is imported anywhere else.",
        "There is no <i>show original</i> button, toggle or hidden menu anywhere.",
        "Message text and sender identity are never logged, cached or sent to analytics.",
        "Deleting an account keeps published group messages but turns them anonymous and unlinks them.",
    ])
    s += [H2("Data we keep, and for how long")]
    s += [table([
        ["Data", "Who sees it", "Kept"],
        ["Account and profile", "You; others see your public profile (email only you)", "Until you delete your account"],
        ["Group messages", "Group members see approved text; the controller also sees originals", "Until deleted by you, the controller or account deletion"],
        ["Questions and comments", "All signed-in users", "Until deleted"],
        ["Feed activity (opens, saves, Not interested)", "Only used for ranking", "180 days (automatic cleanup)"],
        ["Blocks and reports", "Not shown to the other person", "Until removed or account deletion"],
        ["Saved questions, recent people, sign-in tokens", "Stay on your device", "Until you clear them"],
    ], [52 * mm, 72 * mm, 50 * mm])]
    s += [H2("Safety tools")]
    s += bullets([
        "Review before publish in every group; relevance scores never auto-reject.",
        "Block people; report questions (six reasons, including self-harm, which also points to emergency services) and comments.",
        "Feed likes show names (the feed is public and named); group chat reactions show counts only, so they never reveal an anonymous member.",
        "Questions reported by five different people are hidden automatically.",
        "Personalisation off switch: For You falls back to popular and new, and activity is not recorded.",
        "Rate limits on sign-in and the whole API; photos stripped of hidden details; the minimum age is 18.",
    ])

    # 7 ------------------------------------------------------------------
    s += [PageBreak(), H1("7. Architecture")]
    s += [P("Three parts work together: the Flutter app, the Express API with its PostgreSQL database, and a separate Python worker "
            "that talks to the language model. The database is the single source of truth and also drives live updates and the job queue.", "lead")]
    s += [architecture_diagram(), Spacer(1, 4), P("Figure 1. Components and how they talk to each other.", "small")]
    s += [H2("Components")]
    s += [table([
        ["Component", "Responsibility"],
        ["Flutter app", "One codebase for Android and the web. Feature folders (auth, groups, review, feed, discovery, invites, profile, notifications). Riverpod state, go_router navigation with sign-in and controller guards. Every data source has a Mock and an API implementation, switched by <font face='Courier'>USE_MOCK</font>, so the whole app runs offline as a demo."],
        ["Express API", "TypeScript, Express 5, Zod validation on every input, JWT access tokens with rotating refresh tokens, rate limits, Helmet headers. Mounted at <font face='Courier'>/</font> and <font face='Courier'>/api/v1</font>. Contains the NLP module and the public legal pages."],
        ["PostgreSQL 16", "23 migrations. Triggers call <font face='Courier'>NOTIFY</font> on every change the app cares about; a jobs table works as an outbox with leases, retries and back-off."],
        ["Live updates", "Each API instance <font face='Courier'>LISTEN</font>s to Postgres and pushes Server-Sent Events to signed-in clients, which refetch only what changed. Works across many API instances with no Redis."],
        ["Rewrite worker", "Python. Claims one job at a time over the internal HTTP contract (<font face='Courier'>/internal/pipeline</font>, key-protected), never touches the database and never receives sender identity. Fails honestly when the model is unavailable."],
        ["Feed analysis worker", "Runs inside the API process on its own queue, so feed problems never block group messages."],
    ], [34 * mm, 140 * mm])]
    s += [KeepTogether([H2("Life of a group message"), lifecycle_diagram(), Spacer(1, 4),
                        P("Figure 2. From typing to publishing.", "small")])]
    s += [H2("Key data tables")]
    s += [table([
        ["Table", "Holds"],
        ["users, user_profiles", "Accounts, password hashes, token version, handle, profile, personalisation switch"],
        ["groups, group_members", "Groups by agenda; membership with role (controller or contributor)"],
        ["raw_messages", "Originals, real sender, anonymity flag, AI rewrite and scores, review status (controller only)"],
        ["published_messages", "Approved text, author (empty when anonymous), replies, pins, attachments"],
        ["posts, comments, post_likes", "Community questions, answers and likes"],
        ["user_interests, feed_events", "Interests and feed signals (180-day retention)"],
        ["user_blocks, post_reports", "Blocks and question reports"],
        ["group_invites", "Invite codes with expiry, use limit and revoke time"],
        ["jobs, notifications, media", "Work queue, alerts, uploaded images"],
    ], [44 * mm, 130 * mm])]
    s += [H2("Security at a glance")]
    s += bullets([
        "Argon2 password hashing; short-lived access tokens plus rotating refresh tokens; <i>sign out everywhere</i> by token version.",
        "Every route validates input with Zod and checks membership and role on the server.",
        "The internal worker API is disabled unless a key is configured and is never mounted on public paths.",
        "Images are type-checked from their bytes and stripped of metadata.",
    ])

    # 8 ------------------------------------------------------------------
    s += [PageBreak(), H1("8. Technology and code map")]
    s += [table([
        ["Layer", "Technology"],
        ["App", "Flutter 3.47 (Dart), Riverpod 3, go_router 18, Dio, freezed, flutter_secure_storage, share_plus, qr_flutter"],
        ["API", "Node.js 20+, Express 5, TypeScript, Zod 4, pg, Argon2, Vitest"],
        ["Database", "PostgreSQL 16 with pg_trgm"],
        ["AI worker", "Python 3, standard-library tests, any OpenAI-compatible model server (Ollama locally)"],
        ["Model", "Qwen2.5-3B-Instruct (self-hosted)"],
        ["Delivery", "Docker Compose, GitHub Actions (backend-ci, flutter-ci, pipeline-ci, stack-ci)"],
    ], [30 * mm, 144 * mm])]
    s += [H2("Where things live")]
    s += [table([
        ["Path", "Contents"],
        ["lib/app", "App wiring: router and guards, shell, repository switch (mock or API)"],
        ["lib/features/*", "auth, groups (chat, members, catch up, tone hint), review, feed, discovery (people, profiles, For You, safety), invites, onboarding, notifications, profile, legal"],
        ["lib/core", "Shared models, API client, live updates, UI building blocks, strings, share links"],
        ["backend/src/routes", "One file per area: auth, groups, feed, people, profiles, invites, summaries and more"],
        ["backend/src/nlp", "Text normalisation, fuzzy matching, topics, ranking, search, summaries"],
        ["backend/migrations", "Numbered SQL migrations (001 to 023)"],
        ["pipeline/", "Python rewrite worker and its contract tests"],
        ["assets/legal, backend/legal", "Privacy Policy, Terms, account deletion (kept identical by tests)"],
        ["docs/", "STARTUP_PLAN.md, PLAY_STORE.md, setup guides, this guide"],
        ["API.md, LOGS.md", "The HTTP contract (sections 1 to 68) and the project log with open decisions"],
    ], [42 * mm, 132 * mm])]

    # 9 ------------------------------------------------------------------
    s += [PageBreak(), H1("9. Running, testing and quality")]
    s += [H2("Try it in two minutes (demo mode)")]
    s += [P("The demo build uses built-in sample data and needs no server:", "body"),
          P("<font face='Courier'>flutter run -d web-server --web-port=52000 --dart-define=USE_MOCK=true</font>", "body"),
          P("Sign in with the sample account <font face='Courier'>priya@example.com</font> / <font face='Courier'>secret123</font>. "
            "Priya is a contributor in <i>Making NLP notes</i> and the controller of <i>Dashboard improvements</i>.", "body")]
    s += [H2("Full stack")]
    s += bullets([
        "<b>One command:</b> <font face='Courier'>docker compose up</font> starts Postgres, the API and the worker.",
        "<b>By hand:</b> in <font face='Courier'>backend/</font> run <font face='Courier'>npm install</font>, <font face='Courier'>npm run migrate</font>, <font face='Courier'>npm run dev</font>; start the worker with <font face='Courier'>python -m talkitout_pipeline</font>; run the app with <font face='Courier'>USE_MOCK=false</font> and <font face='Courier'>API_BASE_URL</font>.",
        "<b>Starter content:</b> <font face='Courier'>npm run seed:questions</font> adds 61 questions covering all 30 interests (remove with <font face='Courier'>-- --remove</font>).",
        "Settings live in <font face='Courier'>backend/.env</font> (see <font face='Courier'>.env.example</font>): database, secrets, Google client ID, mail, CORS and the web address used in invite links.",
    ])
    s += [H2("Tests and checks")]
    s += [table([
        ["Suite", "What it covers", "Latest result"],
        ["Backend (Vitest)", "Every route against a real Postgres: auth, groups, review, privacy sweeps, feed, people, blocking, invites, summaries, NLP units", "285 passed"],
        ["App (flutter test)", "Screens and flows: privacy UI rules, review, feed, discovery, safety, invites, onboarding, legal, paging", "All passed"],
        ["Rewrite worker", "Contract, prompt-injection layer, validation, scoring", "Passing in CI"],
        ["Static checks", "dart format, flutter analyze, TypeScript, ESLint", "Clean"],
        ["End to end", "<font face='Courier'>backend/scripts/live-check.mjs</font> against a running stack", "83 of 83 (last run)"],
    ], [34 * mm, 104 * mm, 36 * mm])]
    s += [Spacer(1, 6), P("Every push runs four GitHub Actions workflows. Work lands on a branch and is merged into main by the owner.", "small")]

    # 10 ------------------------------------------------------------------
    s += [PageBreak(), H1("10. API overview")]
    s += [P("The full contract is in API.md (sections 1 to 68). All routes need a signed-in user unless marked public.", "lead")]
    s += [table([
        ["Area", "Main routes", "API.md"],
        ["Auth and account", "/auth/register, /auth/login, /auth/google, refresh tokens, password reset, change password, sign out everywhere, DELETE /users/me", "1-4, 35, 37-40, 48"],
        ["Groups", "/groups, /groups/:id (info, settings), members, leave, invites, /invites/:code, mentions", "5-8, 36, 61, 67-68"],
        ["Messages", "list, send, mine, preview, withdraw, replies, search, pins, polls, photos, reactions, summary", "9-11, 33, 49-51, 63"],
        ["Review", "/groups/:id/review-queue, accept, reject, new rewrite, counts and history", "12-15, 43, 45"],
        ["Feed", "/posts (Latest and For You), search, classify, similar, comments, votes, best answer, follow, edits, likes and Liked by, reports, signals, question to group", "16-23, 42, 46-47, 55-58, 60, 64-66"],
        ["People", "search, suggestions, handles, interests, feed settings, profiles, blocks, their questions", "27-32, 44, 52-54, 57, 59"],
        ["Notifications and live", "/notifications, read, read-all, unread count, /events (SSE)", "24-26, 34, 41"],
        ["Public", "/legal/privacy, /legal/terms, /legal/delete-account, /ready", "62"],
        ["Internal", "/internal/pipeline/claim, result, fail (worker only, key-protected)", "Worker contract"],
    ], [32 * mm, 108 * mm, 34 * mm])]

    # 11 ------------------------------------------------------------------
    s += [PageBreak(), H1("11. Status and what comes next")]
    s += [H2n("Where the project stands")]
    s += bullets([
        "All features in this guide are built, tested and pushed; CI is green.",
        "The Android project is ready for Google Play: real app name, icon, internet permission, release signing from a private key file, legal pages. docs/PLAY_STORE.md has the listing text, Data safety answers and release steps.",
        "Everything runs today on a developer machine. It has not yet been deployed to a public server.",
    ])
    s += [H2n("Needed before launch (owner's accounts)")]
    s += [table([
        ["Item", "Why", "Notes"],
        ["Server with HTTPS", "Phones cannot reach a laptop", "Any Docker host plus managed Postgres"],
        ["Model hosting", "Rewrites need the language model", "A GPU host for Ollama or a hosted model"],
        ["Google Play account", "To publish", "One-time US$25; closed test with 12 testers for 14 days"],
        ["Firebase project", "Push notifications and crash reports", "Not built yet"],
        ["Android build tools", "To produce the upload bundle", "Android command-line tools and free disk space"],
    ], [38 * mm, 58 * mm, 78 * mm])]
    s += [H2n("Open decisions")]
    s += bullets([
        "<b>D23</b>: five reports hide a question for everyone (there is no moderator role yet).",
        "<b>D24</b>: blocking does not change groups both people are already in.",
        "<b>D25</b>: minimum age 18.",
        "<b>D26</b>: only controllers create invite links; links last 7 days by default.",
    ])
    s += [H2n("Roadmap")]
    s += [table([
        ["Phase", "Focus"],
        ["Next", "Deploy, push notifications, crash reporting, verified app links, Google sign-up shows the welcome tour"],
        ["Then", "Meaning-based search with embeddings, thread summaries for controllers, smart replies, Nepali and Hindi"],
        ["Later", "Organisation workspaces, admin and moderation tools, analytics dashboards, iOS"],
    ], [24 * mm, 150 * mm])]
    s += [H2n("Glossary")]
    s += [table([
        ["Term", "Meaning"],
        ["Controller", "The person who controls a group: reviews messages and manages members"],
        ["Contributor", "A group member who sends messages for review"],
        ["Rewrite", "The calm version of a message made by the language model"],
        ["Published message", "A message the controller accepted; the only kind the group sees"],
        ["For You", "The feed ranked for each person, with a reason for every question"],
        ["Catch up", "An automatic, name-free summary of a group conversation"],
        ["Invite link", "A shareable link or QR code that lets someone join a group"],
    ], [34 * mm, 140 * mm], zebra=False)]
    return s


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    doc = GuideDoc(OUT)
    doc.multiBuild(story())
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
