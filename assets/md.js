/* 极简 Markdown 渲染器：标题、粗体、斜体、删除线、代码、引用、列表、链接、图片、分割线 */
(function () {
  function esc(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  }

  function inline(s) {
    s = esc(s);
    s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
    s = s.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, '<img src="$2" alt="$1">');
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>');
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/(^|[^*\w])\*([^*\n]+)\*/g, '$1<em>$2</em>');
    s = s.replace(/~~([^~]+)~~/g, '<del>$1</del>');
    return s;
  }

  function parse(src) {
    var lines = String(src).replace(/\r\n?/g, '\n').split('\n');
    var title = '';
    var start = 0;

    var first = lines[0] || '';
    var tm = first.match(/^#\s+(.+)$/);
    if (tm) { title = tm[1].trim(); start = 1; }

    var out = [];
    var para = [];
    var list = null;
    var quote = [];
    var fence = null;

    function flushPara() {
      if (para.length) { out.push('<p>' + inline(para.join(' ')) + '</p>'); para = []; }
    }
    function flushList() {
      if (list) {
        out.push('<' + list.tag + '>' + list.items.map(function (x) {
          return '<li>' + inline(x) + '</li>';
        }).join('') + '</' + list.tag + '>');
        list = null;
      }
    }
    function flushQuote() {
      if (quote.length) {
        out.push('<blockquote>' + quote.map(function (x) {
          return '<p>' + inline(x) + '</p>';
        }).join('') + '</blockquote>');
        quote = [];
      }
    }
    function flushAll() { flushPara(); flushList(); flushQuote(); }

    for (var i = start; i < lines.length; i++) {
      var line = lines[i];

      if (fence) {
        if (/^```/.test(line)) {
          out.push('<pre><code>' + esc(fence.join('\n')) + '</code></pre>');
          fence = null;
        } else {
          fence.push(line);
        }
        continue;
      }

      if (/^```/.test(line)) { flushAll(); fence = []; continue; }
      if (!line.trim()) { flushAll(); continue; }

      var m;

      if ((m = line.match(/^(#{1,6})\s+(.*)$/))) {
        flushAll();
        var lv = Math.min(m[1].length + 1, 6); /* 文章内 # 作为 h2，因为 h1 已是标题 */
        out.push('<h' + lv + '>' + inline(m[2]) + '</h' + lv + '>');
        continue;
      }

      if (/^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/.test(line)) { flushAll(); out.push('<hr>'); continue; }

      if ((m = line.match(/^>\s?(.*)$/))) { flushPara(); flushList(); quote.push(m[1]); continue; }

      if ((m = line.match(/^\s*[-*+]\s+(.*)$/))) {
        flushPara(); flushQuote();
        if (!list || list.tag !== 'ul') { flushList(); list = { tag: 'ul', items: [] }; }
        list.items.push(m[1]);
        continue;
      }

      if ((m = line.match(/^\s*\d+[.)]\s+(.*)$/))) {
        flushPara(); flushQuote();
        if (!list || list.tag !== 'ol') { flushList(); list = { tag: 'ol', items: [] }; }
        list.items.push(m[1]);
        continue;
      }

      flushList(); flushQuote();
      para.push(line.trim());
    }

    if (fence) out.push('<pre><code>' + esc(fence.join('\n')) + '</code></pre>');
    flushAll();

    if (!title) title = '无标题';

    return { title: title, body: out.join('\n') };
  }

  window.md = { parse: parse, esc: esc };
})();
