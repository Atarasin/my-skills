/**
 * Tailwind config for the offline single-file build.
 * src.html 的绝对路径从环境变量 SRC_HTML 读入（相对路径会按 cwd 解析，容易踩坑）。
 *
 * 用法：
 *   SRC_HTML/abs/path/to/src.html node <tailwindcss>/lib/cli.js -c tailwind.config.js -i input.css -o out.css --minify
 */
const src = process.env.SRC_HTML;
if (!src) {
  throw new Error('SRC_HTML 未设置：请传 src.html 的绝对路径，例如 SRC_HTML=E:/proj/tmp/viz1/src.html');
}

module.exports = {
  content: [src],
  theme: { extend: {} },
  plugins: [],
};
