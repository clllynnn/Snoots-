import { useEffect, useRef, useState } from "react";
import {
  ArrowRight,
  ArrowUpRight,
  ChatCircleDots,
  CheckCircle,
  Dog,
  FirstAid,
  Info,
  MapPin,
  PawPrint,
  Play,
  ShieldCheck,
  Sparkle,
  X,
} from "@phosphor-icons/react";

const screenshots = {
  nearby: {
    src: "/assets/app-nearby.png",
    alt: "Snoots 附近探索：狗聚分類、台北地圖與活動結果",
  },
  match: {
    src: "/assets/app-match.png",
    alt: "Snoots 找狗朋友：Mochi 配對卡片",
  },
  chat: {
    src: "/assets/app-chat.png",
    alt: "Snoots 與 Elena 的配對聊天畫面",
  },
  createMeetup: {
    src: "/assets/app-create-meetup.png",
    alt: "Snoots 發起狗聚活動設定畫面",
  },
  community: {
    src: "/assets/app-community.png",
    alt: "Snoots 社群動態與狗聚入口",
  },
  profile: {
    src: "/assets/app-profile.png",
    alt: "Snoots Nori 的檔案與健康照護資訊",
  },
};

const problems = [
  {
    icon: Info,
    title: "寵物友善，規則卻不透明",
    copy: "到了現場才發現有體重、座位、室內外或牽繩限制。",
  },
  {
    icon: MapPin,
    title: "附近活動，散落在各個群組",
    copy: "LINE 群和社團很熱鬧，卻很難快速找到這週附近能參加的活動。",
  },
  {
    icon: Dog,
    title: "陌生狗聚，不知道適不適合牠",
    copy: "看得到活動，卻看不懂現場犬隻、活動方式與場地會不會造成壓力。",
  },
];

const journeySteps = [
  {
    number: "01",
    title: "附近探索",
    copy: "用狗聚、用餐、公園與獸醫院分類，把現在真的能去的地方先找出來。",
  },
  {
    number: "02",
    title: "看懂活動與場地",
    copy: "牽繩、體型、室內外、距離與最後確認時間，一眼看清楚。",
  },
  {
    number: "03",
    title: "AI 適合度建議",
    copy: "依照狗狗、活動與場地資訊，說明適合或需要留意的原因。",
  },
  {
    number: "04",
    title: "安心參加",
    copy: "準備好再報名，把線上的認識帶到真實世界。",
  },
];

function Brand() {
  return (
    <a className="brand" href="#top" aria-label="Snoots 首頁">
      <img src="/assets/logo.png" alt="" />
      <span>Snoots!</span>
    </a>
  );
}

function Screenshot({ image, label, onOpen, priority = false }) {
  return (
    <button className="screenshot" onClick={() => onOpen(image)} aria-label={`放大查看：${label}`}>
      <img src={image.src} alt={image.alt} loading={priority ? "eager" : "lazy"} />
      <span>點一下看完整畫面 <ArrowUpRight weight="regular" /></span>
    </button>
  );
}

function VideoBanner() {
  const videoRef = useRef(null);
  const [isEngaged, setIsEngaged] = useState(false);
  const [shouldAutoplay] = useState(() => (
    typeof window !== "undefined" && !window.matchMedia("(prefers-reduced-motion: reduce)").matches
  ));

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !shouldAutoplay) return undefined;
    video.play().catch(() => {});
    return () => video.pause();
  }, [shouldAutoplay]);

  const engageFilm = () => {
    if (isEngaged) return;
    const video = videoRef.current;
    if (!video) return;
    video.currentTime = 0;
    setIsEngaged(true);
    video.play().catch(() => {});
  };

  return (
    <section className={`video-banner${isEngaged ? " is-engaged" : ""}`} aria-labelledby="hero-title">
      <video
        ref={videoRef}
        className="video-banner__media"
        src="/assets/snoots-product-film-web.m4v"
        poster="/assets/snoots-product-film-poster.jpg"
        autoPlay={shouldAutoplay}
        muted
        loop
        controls={isEngaged}
        playsInline
        preload="auto"
        aria-label="Snoots 產品介紹影片"
      >
        你的瀏覽器目前無法播放這支影片。
      </video>

      <div className="video-banner__content" aria-hidden={isEngaged} inert={isEngaged}>
        <p className="eyebrow eyebrow--light"><PawPrint weight="regular" /> 給每一個想安心出門的你</p>
        <h1 id="hero-title">
          <span>從暸解你的狗狗開始，</span>
          <span>再一起探索世界。</span>
        </h1>
        <p>Snoots 把分散的狗友、場地規則與活動資訊整理好，再用 AI 陪你判斷：這一次，適合牠嗎？</p>
        <div className="hero-actions">
          <a className="button button--lime" href="#experience">探索 Snoots <ArrowRight weight="regular" /></a>
          <button className="button button--white" onClick={engageFilm} aria-label="觀看 15 秒 Snoots 產品介紹影片"><Play weight="fill" /> 觀看 15 秒介紹</button>
        </div>
      </div>

      <div className="video-banner__meta">
        <span>16:9 PRODUCT FILM</span>
        <span>00:00 / 00:15</span>
      </div>
    </section>
  );
}

function Problems() {
  return (
    <section className="problems section-pad" id="why">
      <div className="section-heading">
        <p className="eyebrow">出門前，總有這些不確定。</p>
        <h2>不是沒有選擇，<br />是資訊還不夠讓人放心。</h2>
      </div>
      <div className="problem-grid">
        {problems.map(({ icon: Icon, title, copy }) => (
          <article key={title}>
            <Icon weight="regular" />
            <div><h3>{title}</h3><p>{copy}</p></div>
          </article>
        ))}
      </div>
    </section>
  );
}

function Journey({ onOpen }) {
  return (
    <section className="journey section-pad" id="experience">
      <div className="journey__intro">
        <p className="eyebrow">核心體驗</p>
        <h2>
          <span>從附近探索，</span>
          <span>走到安心參加。</span>
        </h2>
        <p>Snoots 不以增加 App 停留時間為目標。我們想縮短的是「找到資訊」到「真的帶狗出門見面」的距離。</p>
        <a className="text-link" href="#match">也可以先找到想認識的狗 <ArrowRight weight="regular" /></a>
      </div>

      <div className="journey__screen">
        <Screenshot image={screenshots.nearby} label="附近探索" onOpen={onOpen} priority />
      </div>

      <div className="journey__steps">
        {journeySteps.map((step) => (
          <article key={step.number} className={step.number === "03" ? "is-ai" : ""}>
            <span>{step.number}</span>
            <div><h3>{step.title}</h3><p>{step.copy}</p></div>
          </article>
        ))}
      </div>
    </section>
  );
}

function SocialFlow({ onOpen }) {
  const flow = [
    {
      number: "01",
      title: "先找到想認識的狗",
      copy: "看懂個性、互動偏好與驗證資訊，再決定要不要認識。",
      image: screenshots.match,
    },
    {
      number: "02",
      title: "從一句友善的問候開始",
      copy: "配對成功後先聊聊散步方式，讓彼此知道第一次見面需要什麼。",
      image: screenshots.chat,
    },
    {
      number: "03",
      title: "為合拍的狗狗發起相聚",
      copy: "清楚設定活動類型、時間與地點，讓每一次見面都能安心開始。",
      image: screenshots.createMeetup,
    },
  ];

  return (
    <section className="social-flow section-pad" id="match">
      <div className="social-flow__heading">
        <p className="eyebrow">另一條路</p>
        <h2><span>先找到對的夥伴，</span><span>再一起開啟新的冒險。</span></h2>
        <p>滑卡只是認識的開始。Snoots 讓配對、聊天與發起狗聚成為一條完整的線下見面路徑。</p>
      </div>

      <div className="social-flow__grid">
        {flow.map((item) => (
          <article key={item.number}>
            <div className="flow-copy"><span>{item.number}</span><h3>{item.title}</h3><p>{item.copy}</p></div>
            <Screenshot image={item.image} label={item.title} onOpen={onOpen} />
          </article>
        ))}
      </div>
    </section>
  );
}

function MoreFeatures({ onOpen }) {
  return (
    <section className="more-features section-pad" id="features">
      <div className="section-heading section-heading--split">
        <div><p className="eyebrow">完整功能</p><h2><span>更多功能，</span><span>守護每一次出門。</span></h2></div>
        <p>從社群裡看見真實互動，也把狗狗的個性與照護資訊放在同一個地方。需要幫助時，緊急照護仍然保持清楚、直接而且隨時可用。</p>
      </div>

      <div className="feature-grid">
        <article className="feature feature--community">
          <div className="feature__copy"><ChatCircleDots weight="regular" /><h3>社群動態</h3><p>看看附近狗友的日常，也能直接檢視或發起狗聚。</p></div>
          <Screenshot image={screenshots.community} label="社群動態" onOpen={onOpen} />
        </article>

        <article className="feature feature--profile">
          <div className="feature__copy"><PawPrint weight="regular" /><h3>狗狗檔案與照護重點</h3><p>把互動標籤、飲水、餵食、疫苗與健康備註整理在一起。</p></div>
          <Screenshot image={screenshots.profile} label="狗狗檔案" onOpen={onOpen} />
        </article>

        <article className="feature feature--care">
          <div className="feature__copy"><FirstAid weight="regular" /><h3>緊急照護地圖層</h3><p>需要時立即看到夜間急診、電話、導航入口與最後確認時間。基本安全資訊不會被鎖在付費牆後面。</p></div>
          <div className="care-facts">
            <span><CheckCircle weight="fill" /> 24 小時與夜間急診</span>
            <span><CheckCircle weight="fill" /> 距離、電話與導航</span>
            <span><CheckCircle weight="fill" /> 最後確認時間</span>
          </div>
        </article>
      </div>
    </section>
  );
}

function Trust() {
  return (
    <section className="trust section-pad" id="safety">
      <div className="trust__heading">
        <Sparkle weight="regular" />
        <div><p className="eyebrow">AI 的界線</p><h2>AI 是指引，<br />不是保證。</h2></div>
      </div>
      <p className="trust__lede">Snoots 的 AI 會把自家狗狗、活動方式與場地規則放在一起，給你能理解的建議；最後的判斷，仍然回到主人與現場資訊。</p>
      <div className="trust__rules">
        <article><ShieldCheck weight="regular" /><strong>不保證安全</strong><p>AI 不保證狗狗不會衝突，也不會自動核准報名。</p></article>
        <article><FirstAid weight="regular" /><strong>不做醫療診斷</strong><p>急診資訊幫助你採取行動，不取代合格獸醫的判斷。</p></article>
        <article><PawPrint weight="regular" /><strong>不憑品種猜個性</strong><p>建議只使用主人、主揪與已確認的場地資料。</p></article>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="footer-cta" id="download">
      <div className="footer-cta__main">
        <p className="eyebrow">準備好，一起出門</p>
        <h2>把線上的認識，<br />帶到真實世界。</h2>
        <p>從附近的一次散步開始，陪牠找到真正適合的新朋友。</p>
        <a className="button button--dark" href="#top">探索 Snoots <ArrowUpRight weight="regular" /></a>
      </div>
      <div className="footer-cta__bottom"><Brand /><span>© 2026 Snoots!　給每一個想安心出門的你。</span></div>
    </footer>
  );
}

function Modal({ image, onClose }) {
  useEffect(() => {
    if (!image) return undefined;
    const onKeyDown = (event) => { if (event.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [image, onClose]);

  if (!image) return null;

  return (
    <div className="modal modal--image" role="dialog" aria-modal="true" onMouseDown={onClose}>
      <div className="modal__panel" onMouseDown={(event) => event.stopPropagation()}>
        <button className="modal__close" onClick={onClose} aria-label="關閉"><X weight="regular" /></button>
        <img src={image.src} alt={image.alt} />
      </div>
    </div>
  );
}

export function App() {
  const [modal, setModal] = useState(null);

  return (
    <>
      <header className="site-nav" id="top">
        <Brand />
        <nav aria-label="網站主要導覽">
          <a href="#why">為什麼 Snoots</a>
          <a href="#experience">探索</a>
          <a href="#match">配對</a>
          <a href="#features">功能</a>
          <a href="#safety">安全界線</a>
        </nav>
        <a className="button button--lime button--small" href="#download">下載 iOS App <ArrowUpRight weight="regular" /></a>
      </header>

      <main>
        <VideoBanner />
        <Problems />
        <Journey onOpen={setModal} />
        <SocialFlow onOpen={setModal} />
        <MoreFeatures onOpen={setModal} />
        <Trust />
        <Footer />
      </main>

      <Modal image={modal} onClose={() => setModal(null)} />
    </>
  );
}
