var $$e = {}, window = {}, document = {}, navigator = {}, location = { hash: "" },
    setTimeout = function (f, t) { $$e.timeout = t; f(); },
    setInterval = function (f, t) { f(); };

window.addEventListener = function () {};
window.navigator = { userAgent: '%s' };

navigator.cookieEnabled = true;

document.addEventListener = function (e, b, c) { b(); };
document.body = { appendChild: function () {} };

document.getElementById = function (id) {
    if (!$$e[id]) $$e[id] = { style: {}, action: "", submit: function () {} };
    return $$e[id];
};

document.createElement = function (tag) {
    return { firstChild: { href: "%s" }, setAttribute: function () {} };
};

String.prototype.big = function () { return "<big>" + this + "</big>"; };
String.prototype.small = function () { return "<small>" + this + "</small>"; };
String.prototype.bold = function () { return "<b>" + this + "</b>"; };
String.prototype.italics = function () { return "<i>" + this + "</i>"; };
String.prototype.fixed = function () { return "<tt>" + this + "</tt>"; };
String.prototype.strike = function () { return "<strike>" + this + "</strike>"; };
String.prototype.sub = function () { return "<sub>" + this + "</sub>"; };
String.prototype.sup = function () { return "<sup>" + this + "</sup>"; };
