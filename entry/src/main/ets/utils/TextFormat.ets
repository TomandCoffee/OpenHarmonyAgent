/**
 * 把模型输出的轻量 Markdown 剥成纯文本。
 *
 * 聊天界面和知识库卡片都只渲染纯文本，所以统一走这里，
 * 避免同一段文字在两处显示不一致。
 */
export function stripMarkdown(content: string): string {
  return content
    .replace(/\*\*(.*?)\*\*/g, '$1')   // 粗体 **文字**
    // 流式输出时 ** 可能只到了一半（比如刚打完 "**Soft"），
    // 上面的成对替换处理不了，这里再兜一道，避免界面上闪出星号
    .replace(/\*\*/g, '')
    .replace(/^#{1,6}\s+/gm, '')       // 标题符号 # ##
    .replace(/^[-*]\s+/gm, '• ')       // 无序列表 - / *
    .replace(/^>\s?/gm, '')            // 引用 >
    .replace(/`/g, '');                // 反引号
}

/**
 * 单行预览：折叠换行并截断
 */
export function toPreview(content: string, maxLength: number): string {
  const plain: string = stripMarkdown(content).replace(/\s+/g, ' ').trim();
  if (plain.length <= maxLength) {
    return plain;
  }
  return plain.substring(0, maxLength) + '...';
}
