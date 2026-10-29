// Shared by QML and the Node.js tests. No browser APIs or site scripts execute here.
function clean(text) {
    return text.replace(/<[^>]*>/g, " ").replace(/&#(x[0-9a-f]+|[0-9]+);/gi, function (_, value) {
        return String.fromCharCode(value.charAt(0).toLowerCase() === "x"
            ? parseInt(value.slice(1), 16) : parseInt(value, 10));
    }).replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
        .replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'")
        .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/\s+/g, " ").trim();
}

function field(html, className) {
    var pattern = new RegExp('<div\\s+class="' + className + '(?: [^"]*)?"[^>]*>([\\s\\S]*?)</div>');
    var match = pattern.exec(html);
    return match ? clean(match[1]) : "";
}

function parse(html) {
    var weeks = { "1": {}, "2": {} };
    var dayPattern = /<div\s+class="day"\s+id="day-([12])-([1-7])"[^>]*>/g;
    var matches = [], match;
    while ((match = dayPattern.exec(html)) !== null) {
        matches.push({week: match[1], day: match[2], start: dayPattern.lastIndex, end: match.index});
    }
    if (matches.length === 0) throw new Error("На странице не найдено расписание.");
    var counts = {"1": 0, "2": 0};
    matches.forEach(function (day, index) {
        var fragment = html.slice(day.start, index + 1 < matches.length ? matches[index + 1].end : html.length);
        var lessons = [];
        // Split on actual lesson containers, preserving simultaneous lessons.
        var parts = fragment.split(/<div\s+class="less\s+[^"]*"[^>]*>/);
        parts.slice(1).forEach(function (part) {
            var title = field(part, "title");
            var time = field(part, "time");
            if (!title || !time) throw new Error("Изменился формат пары на сайте.");
            var type = /<div\s+class="ad[^\"]*"[^>]*>([\s\S]*?)(?:<div|<\/div>)/.exec(part);
            lessons.push({title: title, time: time, teacher: field(part, "teacher"),
                room: field(part, "aud"), number: field(part, "couple-number"),
                type: type ? clean(type[1]) : ""});
        });
        weeks[day.week][day.day] = lessons;
        counts[day.week]++;
    });
    // Reject partial/error pages instead of overwriting the offline cache.
    if (counts["1"] < 6 || counts["2"] < 6) throw new Error("Сайт вернул неполную неделю.");
    return {group: field(html, "group-name"), weeks: weeks};
}

function parity(date, invert) {
    // Use civil dates in UTC for arithmetic to avoid daylight-saving transitions.
    var days = Math.floor((Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
        - Date.UTC(2024, 7, 19)) / 86400000);
    var week = Math.floor(days / 7);
    var even = ((week % 2) + 2) % 2 === 1;
    return (invert ? !even : even) ? 2 : 1;
}

function monday(date, offset) {
    var result = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
    result.setDate(result.getDate() - (result.getDay() + 6) % 7 + offset * 7);
    return result;
}
