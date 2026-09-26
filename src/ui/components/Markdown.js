"use client";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

// 문서의 HTML 주석(`<!-- TBD ... -->`, 머리 안내문)은 지우지 않고 흐린 메모로 보인다 — 무엇이 비어 있는지가
// 읽기 모드에서도 보여야 한다. 그 밖의 원시 HTML 은 react-markdown 기본대로 그리지 않는다.
function remarkComments() {
  const note = (v, block) => ({
    type: block ? "paragraph" : "emphasis",
    data: { hName: block ? "div" : "span", hProperties: { className: ["md-comment"] } },
    children: [{ type: "text", value: v.replace(/^<!--|-->$/g, "").trim() }],
  });
  const walk = (node, block) => {
    if (!node.children) return;
    node.children = node.children.map((c) =>
      c.type === "html" && /^<!--[\s\S]*-->$/.test(c.value.trim()) ? note(c.value.trim(), block) : c);
    node.children.forEach((c) => walk(c, c.type === "root" || c.type === "blockquote" || c.type === "listItem"));
  };
  return (tree) => walk(tree, true);
}

export default function Markdown({ children }) {
  if (!children?.trim()) return <p className="muted small">(비어 있다)</p>;
  return <div className="md"><ReactMarkdown remarkPlugins={[remarkGfm, remarkComments]}>{children}</ReactMarkdown></div>;
}
