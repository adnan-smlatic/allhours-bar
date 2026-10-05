import Image from "next/image";
import { site } from "@/site.config";
import appIcon from "@/assets/app-icon.png";
import dashboard from "@/assets/dashboard-dark.webp";
import onBreak from "@/assets/break-dark.webp";
import settings from "@/assets/settings-dark.webp";
import signIn from "@/assets/signin-dark.webp";

export default function Home() {
  return (
    <>
      <Hero />
      <main>
        <Workday />
        <Screens />
        <Install />
      </main>
      <Footer />
    </>
  );
}

/* ---------------------------------------------------------------- Hero */

function Hero() {
  return (
    <header className="board relative overflow-hidden">
      <div className="dot-grid absolute inset-0" aria-hidden />
      <div className="relative mx-auto max-w-6xl px-5 sm:px-8">
        <nav className="flex items-center justify-between py-5" aria-label="Main">
          <a href="#" className="flex items-center gap-2.5 rounded-lg">
            <Image src={appIcon} alt="" width={30} height={30} priority />
            <span className="wide text-[15px] font-bold tracking-tight text-white">{site.name}</span>
          </a>
          <div className="flex items-center gap-2 text-sm font-medium">
            <a href={site.repo} className="hidden items-center gap-2 rounded-full px-3.5 py-2 text-mist/85 transition hover:bg-white/10 hover:text-white sm:inline-flex">
              <GitHubMark className="size-4" />
              GitHub
            </a>
            <a href={site.download} className="rounded-full bg-white/12 px-4 py-2 text-white ring-1 ring-white/15 transition hover:bg-white/20">
              Download
            </a>
          </div>
        </nav>

        <div className="grid items-center gap-16 pb-20 pt-8 sm:pt-12 lg:grid-cols-[1.08fr_1fr] lg:gap-10 lg:pb-28 lg:pt-16">
          <div>
            <h1 className="wide text-[clamp(2.8rem,6.4vw,5.3rem)] font-extrabold leading-[0.92] tracking-[-0.035em] text-balance text-white">
              Stop forgetting to clock&nbsp;in.
            </h1>
            <p className="mt-7 max-w-[34rem] text-[17px] leading-relaxed text-mist/85 sm:text-lg">
              All Hours Bar puts your All Hours attendance in the Mac menu bar. See whether you&rsquo;re clocked in and
              how long you&rsquo;ve worked, clock in or out with one click, and get a reminder when you forget.
            </p>
            <div className="mt-9 flex flex-wrap items-center gap-3">
              <a
                href={site.download}
                className="inline-flex items-center gap-2.5 rounded-full bg-signal px-6 py-3.5 text-[15px] font-semibold text-ink shadow-[0_10px_30px_-10px_rgb(61_219_176/0.7)] transition hover:brightness-105 active:translate-y-px"
              >
                <DownloadGlyph className="size-[18px]" />
                Download for Mac
              </a>
              <a
                href={site.repo}
                className="inline-flex items-center gap-2.5 rounded-full px-5 py-3.5 text-[15px] font-medium text-white ring-1 ring-white/25 transition hover:bg-white/10"
              >
                <GitHubMark className="size-[18px]" />
                View source
              </a>
            </div>
            <p className="mt-5 font-mono text-[11.5px] text-mist/60">
              v{site.version} · Unofficial · Free &amp; open source · macOS&nbsp;14+ · Apple Silicon &amp; Intel
            </p>
          </div>

          <MenuBarDemo />
        </div>
      </div>
    </header>
  );
}

/** A slice of macOS: the menu bar with the app's item, which opens the real menu (no JavaScript involved). */
function MenuBarDemo() {
  return (
    <div className="relative mx-auto w-full max-w-[540px] lg:mx-0 lg:justify-self-end">
      <div
        className="relative h-[540px] rounded-[20px] shadow-[0_40px_80px_-30px_rgb(10_16_26/0.65)] ring-1 ring-white/20 sm:h-[580px]"
        style={{
          background:
            "radial-gradient(30rem 22rem at 15% 20%, rgb(61 219 176 / 0.55), transparent 65%), radial-gradient(26rem 24rem at 90% 90%, rgb(27 63 143 / 0.9), transparent 70%), linear-gradient(150deg, #2c9e93, #1a6bcc 55%, #1b3478)",
        }}
      >
        <div className="flex h-8 items-center justify-between rounded-t-[20px] bg-black/25 px-4 font-system text-[13px] text-white backdrop-blur-xl">
          <div className="flex items-center gap-4">
            <span className="font-semibold">Finder</span>
            <span className="hidden text-white/85 sm:inline">File</span>
            <span className="hidden text-white/85 sm:inline">Edit</span>
            <span className="hidden text-white/85 md:inline">View</span>
          </div>
          <div className="flex items-center gap-3">
            <details open className="menu-item group">
              <summary
                aria-label="All Hours Bar: 6 hours 38 minutes worked today. Toggle menu."
                className="flex cursor-pointer select-none items-center gap-1.5 rounded-[5px] px-1.5 py-[3px] transition group-open:bg-white/25 hover:bg-white/15"
              >
                <ClockGlyph className="size-[15px]" />
                <span className="worked-clock font-medium tabular-nums" aria-hidden />
              </summary>
              <div className="popover absolute right-3 top-10 z-10 w-[min(300px,calc(100%-1.5rem))] origin-top-right">
                <Image
                  src={dashboard}
                  alt="The All Hours Bar menu: at work, 6 hours 38 minutes worked today, a Clock Out button, buttons for lunch and a business trip, today's clockings, and balance, breaks and vacation days."
                  sizes="300px"
                  priority
                  className="rounded-[14px] shadow-[0_24px_60px_-12px_rgb(0_0_0/0.55)] ring-1 ring-black/30"
                />
              </div>
            </details>
            <WifiGlyph className="hidden h-[13px] w-4 sm:block" />
            <BatteryGlyph className="hidden h-3 w-6 sm:block" />
            <span className="tabular-nums">
              <span className="hidden sm:inline">Mon 5 Oct&nbsp;&nbsp;</span>15:12
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------- Workday */

const workday = [
  {
    time: "08:04",
    tag: "Reminder",
    reminder: true,
    title: "Your Mac wakes up. You haven’t clocked in.",
    body: "On weekdays, the first unlock after your start time brings a notification with the clock-in button right in it.",
  },
  {
    time: "08:05",
    tag: "Clock in",
    title: "One click from the menu bar.",
    body: "The same buttons your company gives you on pro.allhours.com, minus the browser tab. Clicked the wrong one? Undo it within 10 seconds.",
  },
  {
    time: "12:01",
    tag: "Break",
    title: "Lunch without logging in anywhere.",
    body: "Breaks, business trips and working from home work the same way, and time away is kept apart from time worked.",
  },
  {
    time: "15:12",
    tag: "Glance",
    title: "Your day, one click away.",
    body: "The menu bar shows today’s time as it grows. Open it for every clocking, your daily goal, balance and vacation days left.",
  },
  {
    time: "17:00",
    tag: "Reminder",
    reminder: true,
    title: "Still clocked in?",
    body: "At the time you pick, a reminder with a Clock Out button, so you don’t leave the office on the clock.",
  },
];

function Workday() {
  return (
    <section className="bg-ledger text-ink" aria-labelledby="workday-title">
      <div className="mx-auto grid max-w-6xl gap-12 px-5 py-24 sm:px-8 lg:grid-cols-[0.85fr_1.15fr] lg:gap-16 lg:py-32">
        <div className="lg:sticky lg:top-16 lg:self-start">
          <h2 id="workday-title" className="wide text-[clamp(2.2rem,4.4vw,3.4rem)] font-extrabold leading-[0.95] tracking-[-0.03em] text-balance">
            It keeps an eye on the clock for you.
          </h2>
          <p className="mt-6 max-w-md text-[17px] leading-relaxed text-ink/70">
            Most missed clockings aren&rsquo;t laziness. You sat down, started working and the browser tab was
            never opened. All Hours Bar sits where you already look.
          </p>
        </div>

        <div className="relative rounded-md bg-paper shadow-[0_1px_0_var(--color-rule),0_30px_60px_-30px_rgb(17_25_37/0.4)] ring-1 ring-rule">
          <div className="punch-holes absolute inset-y-0 left-0 w-9 border-r border-dashed border-rule" aria-hidden />
          <div className="flex items-center justify-between border-b-2 border-ink/85 py-3 pl-14 pr-6 font-mono text-[10.5px] uppercase tracking-[0.18em] text-ink/80">
            <span>Time card</span>
            <span className="hidden sm:inline">Weekday</span>
          </div>
          <ol>
            {workday.map((row) => (
              <li
                key={row.time}
                className="grid grid-cols-1 gap-x-6 gap-y-3 border-b border-rule py-6 pl-14 pr-6 last:border-b-0 sm:grid-cols-[132px_1fr]"
              >
                <div className="flex items-baseline gap-3 sm:block">
                  <DotTime value={row.time} className={row.reminder ? "-rotate-2 text-stamp" : "text-ink"} />
                  <span className={`font-mono text-[10.5px] uppercase tracking-[0.18em] sm:mt-2.5 sm:block ${row.reminder ? "text-stamp" : "text-ink/55"}`}>
                    {row.tag}
                  </span>
                </div>
                <div>
                  <h3 className="text-[17px] font-semibold leading-snug">{row.title}</h3>
                  <p className="mt-1.5 text-[15px] leading-relaxed text-ink/70">{row.body}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}

/** "08:04" in the dot-matrix face, with a drawn colon (Doto's own colon reads like a dagger). */
function DotTime({ value, className = "" }: { value: string; className?: string }) {
  const [hours, minutes] = value.split(":");
  return (
    <time dateTime={value} aria-label={value} className={`inline-flex items-center font-dots text-[34px] leading-none ${className}`}>
      <span aria-hidden>{hours}</span>
      <span className="dot-colon" aria-hidden />
      <span aria-hidden>{minutes}</span>
    </time>
  );
}

/* ------------------------------------------------------------- Screens */

const screens = [
  { image: signIn, caption: "Sign in on All Hours’ own login page.", alt: "The sign-in screen with a Sign in with All Hours button." },
  { image: onBreak, caption: "On a break: back to work in one click.", alt: "The menu during a lunch break, with a Back to Work button." },
  { image: settings, caption: "Reminder times, the menu bar timer, open at login.", alt: "The settings page with reminder times and toggles." },
];

function Screens() {
  return (
    <section className="board relative overflow-hidden" aria-labelledby="screens-title">
      <div className="dot-grid absolute inset-0" aria-hidden />
      <div className="relative mx-auto max-w-6xl px-5 py-24 sm:px-8 lg:py-32">
        <h2 id="screens-title" className="wide max-w-2xl text-[clamp(2.2rem,4.4vw,3.4rem)] font-extrabold leading-[0.95] tracking-[-0.03em] text-balance text-white">
          Small on purpose.
        </h2>
        <p className="mt-5 max-w-lg text-[17px] leading-relaxed text-mist/80">
          No dashboard to learn. Your status, today&rsquo;s clockings and a few settings, all native SwiftUI.
        </p>
        <div className="-mx-5 mt-14 flex snap-x snap-mandatory gap-6 overflow-x-auto px-5 pb-4 sm:-mx-8 sm:px-8 lg:mx-0 lg:grid lg:grid-cols-3 lg:items-start lg:gap-8 lg:overflow-visible lg:px-0">
          {screens.map((screen) => (
            <figure key={screen.caption} className="w-[78%] shrink-0 snap-center sm:w-[300px] lg:w-auto">
              <Image
                src={screen.image}
                alt={screen.alt}
                sizes="(min-width: 1024px) 30vw, 300px"
                className="w-full rounded-[14px] shadow-[0_30px_60px_-25px_rgb(5_10_20/0.7)] ring-1 ring-black/25"
              />
              <figcaption className="mt-4 font-mono text-[12px] leading-relaxed text-mist/75">{screen.caption}</figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------- Install */

const steps = [
  <>
    <a href={site.download} className="font-semibold underline decoration-ink/30 underline-offset-4 hover:decoration-ink">
      Download AllHoursBar.dmg
    </a>{" "}
    and open it.
  </>,
  <>Drag All Hours Bar into Applications.</>,
  <>
    Open the app. It isn&rsquo;t notarized by Apple, so macOS blocks the first launch: go to{" "}
    <span className="font-medium">System Settings › Privacy &amp; Security</span> and click{" "}
    <span className="font-medium">Open Anyway</span>. You only do this once.
  </>,
  <>
    Click the clock in your menu bar and choose <span className="font-medium">Sign in with All Hours</span>.
  </>,
];

const privacy = [
  "You sign in on All Hours’ own login page, the same one pro.allhours.com uses. The app never sees your password.",
  "Your session is stored in the macOS Keychain. Settings stay on your Mac.",
  "It talks to login.spica.com and api4.allhours.com, nothing else. No analytics, no servers of its own.",
  "It only shows the clock buttons your company already allows on the web.",
];

function Install() {
  return (
    <section id="install" className="bg-ledger text-ink" aria-labelledby="install-title">
      <div className="mx-auto grid max-w-6xl gap-16 px-5 py-24 sm:px-8 lg:grid-cols-[1.1fr_0.9fr] lg:py-32">
        <div className="min-w-0">
          <h2 id="install-title" className="wide text-[clamp(2.2rem,4.4vw,3.4rem)] font-extrabold leading-[0.95] tracking-[-0.03em] text-balance">
            Up and running in a minute.
          </h2>
          <ol className="mt-10 space-y-6">
            {steps.map((step, index) => (
              <li key={index} className="grid grid-cols-[2.75rem_1fr] items-baseline">
                <span className="font-dots text-[26px] leading-none text-ink/80" aria-hidden>
                  {index + 1}
                </span>
                <p className="text-[16.5px] leading-relaxed text-ink/80">{step}</p>
              </li>
            ))}
          </ol>

          <div className="mt-12">
            <p className="text-[15px] font-semibold">Rather build it yourself?</p>
            <pre className="mt-3 overflow-x-auto rounded-lg bg-ink px-5 py-4 font-mono text-[13px] leading-relaxed text-mist">
              <code>
                <span className="select-none text-mist/40">$ </span>git clone {site.repo}.git{"\n"}
                <span className="select-none text-mist/40">$ </span>cd allhours-bar &amp;&amp; ./scripts/build.sh --install
              </code>
            </pre>
            <p className="mt-3 text-[14px] text-ink/60">Needs Xcode 16 or newer.</p>
          </div>
        </div>

        <aside className="self-start rounded-md bg-paper p-7 ring-1 ring-rule sm:p-9" aria-labelledby="privacy-title">
          <h3 id="privacy-title" className="wide text-[26px] font-extrabold leading-tight tracking-[-0.02em]">
            Your password stays with All&nbsp;Hours.
          </h3>
          <ul className="mt-6 space-y-4">
            {privacy.map((line) => (
              <li key={line} className="flex gap-3 text-[15.5px] leading-relaxed text-ink/75">
                <span className="mt-[9px] size-1.5 shrink-0 rounded-full bg-ink/40" aria-hidden />
                {line}
              </li>
            ))}
          </ul>
          <a
            href={site.repo}
            className="mt-8 inline-flex items-center gap-2 text-[15px] font-semibold underline decoration-ink/30 underline-offset-4 hover:decoration-ink"
          >
            <GitHubMark className="size-4" />
            Read every line on GitHub
          </a>
        </aside>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------- Footer */

function Footer() {
  return (
    <footer className="bg-ink text-mist/70">
      <div className="mx-auto max-w-6xl px-5 py-12 sm:px-8">
        <div className="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3">
            <Image src={appIcon} alt="" width={36} height={36} />
            <p className="text-[15px]">
              <span className="wide font-bold text-white">{site.name}</span>
              <span className="mx-2 text-mist/30">·</span>
              Made by{" "}
              <a href={site.author.url} className="font-medium text-white underline decoration-white/30 underline-offset-4 hover:decoration-white">
                {site.author.name}
              </a>
            </p>
          </div>
          <div className="flex items-center gap-5 text-[14px]">
            <a href={site.repo} className="inline-flex items-center gap-2 hover:text-white">
              <GitHubMark className="size-4" />
              GitHub
            </a>
            <a href={`${site.repo}/blob/main/LICENSE`} className="hover:text-white">
              MIT License
            </a>
          </div>
        </div>
        <p className="mt-8 max-w-3xl border-t border-white/10 pt-6 text-[12.5px] leading-relaxed text-mist/45">
          All Hours Bar is an independent, unofficial project. It isn&rsquo;t affiliated with, endorsed by or supported
          by All Hours or Spica International. All Hours is a trademark of its owner.
        </p>
      </div>
    </footer>
  );
}

/* --------------------------------------------------------------- Glyphs */

function ClockGlyph({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" className={className} aria-hidden>
      <mask id="clock-hands">
        <circle cx="8" cy="8" r="7" fill="white" />
        <path d="M8 4v4.3h3.2" fill="none" stroke="black" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      </mask>
      <circle cx="8" cy="8" r="7" fill="currentColor" mask="url(#clock-hands)" />
    </svg>
  );
}

function WifiGlyph({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 13" className={className} fill="currentColor" aria-hidden>
      <path d="M8 2.2c2.4 0 4.6.9 6.3 2.5l1.2-1.3A10.7 10.7 0 0 0 8 .4C5.1.4 2.5 1.5.5 3.4l1.2 1.3A9 9 0 0 1 8 2.2Zm0 3.5c1.5 0 2.9.6 4 1.6l1.2-1.3A7.6 7.6 0 0 0 8 3.9 7.6 7.6 0 0 0 2.8 6l1.2 1.3c1.1-1 2.5-1.6 4-1.6Zm0 3.5c.6 0 1.2.2 1.7.6L8 11.6 6.3 9.8c.5-.4 1.1-.6 1.7-.6Z" />
    </svg>
  );
}

function BatteryGlyph({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 26 12" className={className} aria-hidden>
      <rect x="0.5" y="0.5" width="22" height="11" rx="3" fill="none" stroke="currentColor" strokeOpacity="0.5" />
      <rect x="2" y="2" width="15" height="8" rx="1.6" fill="currentColor" />
      <path d="M24 4.2v3.6c.8-.3 1.3-1 1.3-1.8s-.5-1.5-1.3-1.8Z" fill="currentColor" fillOpacity="0.5" />
    </svg>
  );
}

function DownloadGlyph({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 20 20" className={className} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      <path d="M10 3v10m0 0 4-4m-4 4-4-4M4 16h12" />
    </svg>
  );
}

function GitHubMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 16 16" className={className} fill="currentColor" aria-hidden>
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8Z" />
    </svg>
  );
}
