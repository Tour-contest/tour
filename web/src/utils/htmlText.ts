// 관광정보 overview 에는 &amp; &lt;br&gt; 같은 HTML 엔티티와 태그가 섞여 온다 (명세).
// 브라우저 파서로 엔티티만 풀고 태그는 글자로 남기지 않는다 — 렌더링은 항상 텍스트로 한다
export const decodeHtmlText = (raw: string) => {
    const doc = new DOMParser().parseFromString(raw, "text/html");
    return (doc.body.textContent ?? "").replace(/\s+/g, " ").trim();
};
