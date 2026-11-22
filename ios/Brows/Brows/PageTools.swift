import Foundation
import SwiftUI

/// The JavaScript behind find, reader and site information. Kept in one place so
/// the page-side behaviour is inspectable rather than buried in view code.
enum PageTools {
    static let siteInfoJS = """
    (function(){
      function bytes(storage){
        try {
          var total = 0;
          for (var i = 0; i < storage.length; i++) {
            var key = storage.key(i) || "";
            total += key.length + (storage.getItem(key) || "").length;
          }
          return total;
        } catch (e) { return 0; }
      }
      var sw = 0;
      try { sw = 0; } catch (e) {}
      return JSON.stringify({
        host: location.host,
        protocol: location.protocol,
        path: location.pathname + location.search,
        cookies: document.cookie ? document.cookie.split(";").length : 0,
        local: bytes(localStorage),
        session: bytes(sessionStorage),
        scripts: document.scripts.length,
        images: document.images.length,
        serviceWorkers: sw
      });
    })();
    """

    static let readerJS = """
    (function(){
      var preferred = document.querySelector("article") || document.querySelector("main") || document.body;
      if (!preferred) { return JSON.stringify({title: document.title || "", url: location.href, text: ""}); }
      var clone = preferred.cloneNode(true);
      clone.querySelectorAll("script,style,nav,aside,footer,header,form,iframe,button,svg,aside").forEach(function(node){ node.remove(); });
      clone.querySelectorAll("img").forEach(function(img){
        var src = img.getAttribute("src") || img.getAttribute("data-src") || "";
        if (!src) { img.remove(); }
      });
      var text = (clone.innerText || "").replace(/\\n{3,}/g, "\\n\\n").trim();
      return JSON.stringify({title: document.title || "", url: location.href, text: text, html: clone.innerHTML || ""});
    })();
    """

    /// Watches form submissions and reports the credentials the user typed, so the
    /// app can offer to save them — the password manager half that iOS WebKit does
    /// not give a shell for free.
    static let credentialScript = """
    (function(){
      if (window.__browsCredentialHooked) { return; }
      window.__browsCredentialHooked = true;
      function report(form) {
        try {
          var passwords = form.querySelectorAll('input[type="password"]');
          if (passwords.length !== 1) { return; }
          var password = passwords[0].value;
          if (!password) { return; }
          var user = form.querySelector('input[autocomplete="username"], input[type="email"], input[type="text"]');
          window.webkit.messageHandlers.browsCredentials.postMessage({
            host: location.host,
            username: user ? user.value : "",
            password: password
          });
        } catch (e) {}
      }
      document.addEventListener('submit', function(event) {
        if (event.target && event.target.tagName === 'FORM') { report(event.target); }
      }, true);
    })();
    """

    /// Fills the page's login form from a saved credential.
    static func fillJS(username: String, password: String) -> String {
        """
        (function(){
          var user = \(jsString(username));
          var secret = \(jsString(password));
          var passwordField = document.querySelector('input[type="password"]');
          var userField = document.querySelector('input[autocomplete="username"], input[type="email"], input[type="text"]');
          if (userField) {
            userField.value = user;
            userField.dispatchEvent(new Event('input', {bubbles: true}));
            userField.dispatchEvent(new Event('change', {bubbles: true}));
          }
          if (passwordField) {
            passwordField.value = secret;
            passwordField.dispatchEvent(new Event('input', {bubbles: true}));
            passwordField.dispatchEvent(new Event('change', {bubbles: true}));
            passwordField.focus();
          }
          return !!(passwordField);
        })();
        """
    }

    /// Load-time fill: only touches an empty login form, so reloading the page
    /// after the user typed something never overwrites it.
    static func autofillJS(username: String, password: String) -> String {
        """
        (function(){
          var user = \(jsString(username));
          var secret = \(jsString(password));
          var passwordField = document.querySelector('input[type="password"]');
          if (!passwordField || passwordField.value) { return false; }
          var scope = passwordField.form || document;
          var userField = scope.querySelector('input[autocomplete="username"], input[type="email"], input[type="text"]');
          if (userField && !userField.value) {
            userField.value = user;
            userField.dispatchEvent(new Event('input', {bubbles: true}));
            userField.dispatchEvent(new Event('change', {bubbles: true}));
          }
          passwordField.value = secret;
          passwordField.dispatchEvent(new Event('input', {bubbles: true}));
          passwordField.dispatchEvent(new Event('change', {bubbles: true}));
          return true;
        })();
        """
    }

    private static func jsString(_ value: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [value])) ?? Data("[]".utf8)
        let arrayText = String(data: data, encoding: .utf8) ?? "[\"\"]"
        return String(arrayText.dropFirst().dropLast())
    }

    /// Number of matches on the page.
    static func findCountJS(query: String) -> String {
        """
        (function(){
          var query = \(jsString(query));
          if (!query) { return 0; }
          var haystack = document.body ? document.body.innerText : "";
          var lowerHay = haystack.toLowerCase();
          var lowerQuery = query.toLowerCase();
          var total = 0, index = 0;
          while ((index = lowerHay.indexOf(lowerQuery, index)) !== -1) {
            total += 1;
            index += lowerQuery.length;
          }
          return total;
        })();
        """
    }

    /// Step to the next (or previous) match, wrapping inside the page.
    static func findStepJS(query: String, backwards: Bool) -> String {
        """
        (function(){
          var query = \(jsString(query));
          if (!query) { return false; }
          var selection = window.getSelection();
          if (selection) { selection.removeAllRanges(); }
          try { return window.find(query, false, \(backwards ? "true" : "false"), true); }
          catch (e) { return false; }
        })();
        """
    }
}
