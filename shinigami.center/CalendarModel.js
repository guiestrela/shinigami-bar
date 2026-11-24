.pragma library

var MonthNames = [
  "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
  "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
]

function validDate(value) {
  return value instanceof Date && !isNaN(value.getTime())
}

function normalizedDate(value) {
  return validDate(value) ? value : new Date()
}

function monthDate(value, offset) {
  var date = normalizedDate(value)
  return new Date(date.getFullYear(), date.getMonth() + Number(offset || 0), 1)
}

function monthName(value, offset) {
  return MonthNames[monthDate(value, offset).getMonth()]
}

function year(value, offset) {
  return String(monthDate(value, offset).getFullYear())
}

function dateLabel(value) {
  var date = normalizedDate(value)
  var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  return days[date.getDay()] + " " + date.getDate()
}

function dayKey(date) {
  return Qt.formatDate(date, "yyyy-MM-dd")
}

function eventDay(value) {
  if (typeof value !== "string") return ""
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value
  const date = new Date(value)
  return validDate(date) ? dayKey(date) : ""
}

function eventsOn(events, day) {
  return events.filter(function(event) {
    const start = eventDay(event.start)
    if (!start || day < start) return false
    if (day === start) return true
    const end = eventDay(event.end)
    const endTime = new Date(event.end)
    const exclusiveEnd = event.all_day || (validDate(endTime)
      && endTime.getHours() === 0 && endTime.getMinutes() === 0
      && endTime.getSeconds() === 0 && endTime.getMilliseconds() === 0)
    return exclusiveEnd ? day < end : day <= end
  })
}

function cells(value, offset) {
  var today = normalizedDate(value)
  var first = monthDate(today, offset)
  var currentYear = first.getFullYear()
  var currentMonth = first.getMonth()
  var lastDay = new Date(currentYear, currentMonth + 1, 0).getDate()
  var startDay = (first.getDay() + 6) % 7
  var isCurrentMonth = currentYear === today.getFullYear()
    && currentMonth === today.getMonth()
  var result = []

  for (var i = 0; i < startDay; i++)
    result.push({ day: 0, today: false })
  for (var day = 1; day <= lastDay; day++)
    result.push({ day: day, today: isCurrentMonth && day === today.getDate() })
  while (result.length < 42) result.push({ day: 0, today: false })
  return result
}
