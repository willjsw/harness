import "./globals.css";

export const metadata = { title: "Harness" };

export default function RootLayout({ children }) {
  return (
    <html lang="ko" suppressHydrationWarning>
      {/* 화면 설정을 그리기 전에 적용한다 — 파일명이 잠깐 보였다 사라지지 않게 */}
      <head><script dangerouslySetInnerHTML={{ __html: `try{var d=document.documentElement,s=localStorage;if(s.getItem("harness.ui.fname")==="off")d.dataset.fname="off";var t=s.getItem("harness.ui.theme");if(t==="dark"||t==="light")d.dataset.theme=t}catch(e){}` }} /></head>
      <body>{children}</body>
    </html>
  );
}
