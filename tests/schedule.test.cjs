const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const api = vm.createContext({Date});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../package/contents/code/schedule.js'), 'utf8'), api);

const html = fs.readFileSync(path.join(__dirname, 'fixtures/timetable.html'), 'utf8');
const result = api.parse(html);
assert.equal(result.group, 'АПИб-24-1 (1 подгр.)');
assert.equal(Object.keys(result.weeks['1']).length, 6);
assert.equal(Object.keys(result.weeks['2']).length, 6);
const first = result.weeks['1']['1'][0];
assert.equal(first.title, 'Математическое моделирование');
assert.equal(first.teacher, 'Гусева Е.Н.');
assert.equal(first.room, '1-433М');
assert.equal(first.time, '08:30 – 10:00');
assert.equal(first.type, 'Лекция');
assert.equal(first.number, '1');
assert.equal(result.weeks['1']['1'].length, 2);
assert.equal(result.weeks['2']['6'].length, 0);
assert.equal(result.weeks['2']['4'][0].title, 'Основы управленческого учета и бюджетирование');
assert.throws(() => api.parse('<html>Ошибка сервера</html>'));
assert.throws(() => api.parse(html.slice(0, html.indexOf('id="day-2-3"'))));
assert.throws(() => api.parse(html.replace('class="time"', 'class="changed-time"')));
const duplicate = html.replace(/(<div\s+class="less\s+group-0"[^>]*>[\s\S]*?<div class="couple-number">1<\/div>)/, '$1$1');
assert.equal(api.parse(duplicate).weeks['1']['1'].length, 3);
assert.equal(api.clean('A &amp; B&nbsp; &#x41; &#1041;'), 'A & B A Б');

// Weeks change on Monday, regardless of the hour or DST in the local timezone.
for (const hour of [0, 12, 23]) {
    assert.equal(api.parity(new Date(2024, 7, 19, hour), false), 1);
    assert.equal(api.parity(new Date(2024, 7, 25, hour), false), 1);
    assert.equal(api.parity(new Date(2024, 7, 26, hour), false), 2);
    assert.equal(api.parity(new Date(2024, 7, 26, hour), true), 1);
}
assert.equal(api.parity(new Date(2024, 7, 12), false), 2);
assert.equal(api.parity(new Date(2025, 0, 5), false), api.parity(new Date(2024, 11, 30), false));
const monday = api.monday(new Date(2026, 9, 28), 0);
assert.equal(monday.getDay(), 1);
assert.equal(monday.getDate(), 26);
assert.equal(api.monday(new Date(2026, 9, 28), 1).getDate(), 2);
assert.equal(api.monday(new Date(2026, 9, 25), 0).getDate(), 19);
console.log('Schedule parser, partial-page protection, parallel lessons and week calculations passed.');
