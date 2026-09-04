/*
 * ConnectWise Manage Ticket Notes Bookmarklet
 * -------------------------------------------
 * Gathers ALL notes from the "Discussion" tab AND the "Internal" tab of a
 * Service Ticket, organizes them chronologically (oldest first), and copies
 * them to the clipboard as plain text.
 *
 * WHY THIS IS NEEDED: ConnectWise loads one tab's notes at a time and unloads
 * the others when you switch tabs. So no single snapshot of the page contains
 * every note. This bookmarklet automates that by:
 *   1. Clicking the "Discussion" tab, waiting for its notes to render, scraping them.
 *   2. Clicking the "Internal" tab, waiting, scraping them.
 *   3. Merging both sets, sorting by date ascending, and copying as plain text.
 *
 * HOW TO INSTALL AS A BOOKMARKLET
 *   - Open the bookmark manager in your browser and create a new bookmark.
 *   - Set the URL to the minified one-liner at the bottom of this file
 *     (the "javascript:" line). Name it e.g. "Copy CW Notes".
 *   - Open a ConnectWise Service Ticket and click the bookmarklet.
 *
 * NOTE: This relies on ConnectWise's stable DOM classes (TicketNote-*, TimeText-date).
 * If ConnectWise ever changes those, the selectors below need updating.
 */

(function () {
  'use strict';

  var q = function (sel, root) { return (root || document).querySelector(sel); };
  var qa = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };
  var vis = function (el) { return !!(el && el.offsetParent && el.getClientRects().length); };
  var norm = function (s) { return String(s == null ? '' : s).replace(/\s+/g, ' ').trim(); };
  var sleep = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };

  // The notes pod root. First one that exists wins.
  function podRoot() {
    return (
      q('[data-cwid="cw_ticketnotes"]') ||
      q('[data-cwid="pod_service_ticket_notes"]') ||
      q('#cw-manage-service_service_ticket_discussion') ||
      document
    );
  }

  // Find the clickable element for a tab (e.g. "Discussion", "Internal").
  // Tab labels may include a trailing count like "Discussion 12", so compare by prefix.
  function findTab(pod, name) {
    var tables = qa('.TicketNote-ticketNoteTable', pod);
    for (var t = 0; t < tables.length; t++) {
      var all = tables[t].querySelectorAll('*');
      for (var i = 0; i < all.length; i++) {
        var el = all[i];
        if (el.children.length !== 0) continue; // only leaf nodes carry the label text
        var txt = norm(el.textContent).replace(/\s+\d+$/, '').trim();
        if (txt === name) return el;
      }
    }
    return null;
  }

  // Click a tab and wait until it becomes the selected tab and its notes render.
  async function activate(pod, name) {
    var tab = findTab(pod, name);
    if (!tab) return false;
    tab.click();
    for (var i = 0; i < 40; i++) {
      await sleep(100);
      var sel = q('.TicketNote-ticketNoteTabSelected', pod);
      if (sel && norm(sel.textContent).replace(/\s+\d+$/, '').trim() === name) break;
    }
    await sleep(450); // let GWT render the newly loaded rows
    return true;
  }

  // Parse the note's timestamp to a sortable value. Returns 0 if unparseable.
  function parseDate(str) {
    var t = Date.parse(str || '');
    return isNaN(t) ? 0 : t;
  }

  // Scrape the note rows currently visible under the active tab.
  function scrape(pod, type) {
    var out = [];
    var rows = qa('.TicketNote-rowWrap .TicketNote-row, .TicketNote-row', pod);
    rows.forEach(function (row) {
      if (!vis(row)) return;
      var authorEl =
        q('.TicketNote-clickableName, .TicketNote-basicName, .TicketNote-skittleAvatar', row);
      var dateEl = q('.TimeText-date', row);
      var author = authorEl ? norm(authorEl.textContent) : '';
      var date = dateEl ? norm(dateEl.textContent) : '';
      var blocks = qa('.TicketNote-rowNote, .TicketNote-note', row);
      var parts = [];
      blocks.forEach(function (b) {
        var txt = norm(b.innerText);
        if (txt) parts.push(txt);
      });
      var text = Array.from(new Set(parts)).join('\n\n');
      if (author || date || text) {
        out.push({ type: type, author: author, date: date, text: text, ts: parseDate(date) });
      }
    });
    return out;
  }

  function ticketId() {
    try {
      var u = new URL(location.href);
      var p = u.searchParams;
      var id = p.get('service_recid') || p.get('srRecID') || p.get('recid');
      if (id && /^\d{3,}$/.test(id)) return id;
      var m = u.pathname.match(/(?:^|\/)(?:ticket|tickets|sr|service[_-]?ticket)s?\/(\d{3,})/i);
      return m ? m[1] : '';
    } catch (e) { return ''; }
  }

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (e) {}
    try {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      var ok = document.execCommand('copy');
      ta.remove();
      return ok;
    } catch (e) { return false; }
  }

  (async function main() {
    var pod = podRoot();
    if (!pod || pod === document) {
      alert('Could not find the ticket Notes pod on this page.');
      return;
    }

    var all = [];

    // Scrape whichever tab is currently active first, then visit the other two.
    var selTab = q('.TicketNote-ticketNoteTabSelected', pod);
    var activeName = selTab ? norm(selTab.textContent).replace(/\s+\d+$/, '').trim() : '';
    if (activeName === 'Discussion' || activeName === 'Internal') {
      all = all.concat(scrape(pod, activeName));
    }

    if (activeName !== 'Discussion' && (await activate(pod, 'Discussion'))) {
      all = all.concat(scrape(pod, 'Discussion'));
    }
    if (activeName !== 'Internal' && (await activate(pod, 'Internal'))) {
      all = all.concat(scrape(pod, 'Internal'));
    }

    // De-dupe by (type + author + date + text) in case a row was captured twice.
    var seen = {};
    all = all.filter(function (n) {
      var k = n.type + '|' + n.author + '|' + n.date + '|' + n.text;
      if (seen[k]) return false;
      seen[k] = true;
      return true;
    });

    // Chronological (oldest first).
    all.sort(function (a, b) { return a.ts - b.ts; });

    var tid = ticketId();
    var lines = [];
    lines.push('Ticket #' + tid + ' — Discussion & Internal notes (chronological)');
    lines.push('');
    all.forEach(function (n) {
      lines.push('[' + n.type + '] ' + (n.date || '(no date)') + (n.author ? ' — ' + n.author : ''));
      lines.push(n.text || '(no body)');
      lines.push('');
    });

    if (!all.length) {
      alert('No Discussion/Internal notes were found. Make sure you are on a Service Ticket page.');
      return;
    }

    var ok = await copyText(lines.join('\n'));
    if (ok) {
      alert('Copied ' + all.length + ' notes to clipboard (chronological).');
    } else {
      alert('Clipboard blocked. Enable clipboard permission or retry.\n\n' + lines.join('\n'));
    }
  })();
})();
