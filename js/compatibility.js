var hasFlash = (function() {
    try {
        var fo = new ActiveXObject('ShockwaveFlash.ShockwaveFlash');
        if (fo) return true;
    } catch (e) {
        if (navigator.mimeTypes ["application/x-shockwave-flash"] !== undefined) {
            return true;
        }
    }
    return false;
}());

module.exports = {
    hasFlash: hasFlash
}
