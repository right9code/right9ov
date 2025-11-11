<%*  
// Prompt for month in format "YYYY-MM"  
let monthInput = await tp.system.prompt("Enter month (e.g., 2025-08):");  
if (!monthInput) monthInput = tp.date.now("YYYY-MM");

const dateMoment = moment(monthInput, "YYYY-MM");  
if (!dateMoment.isValid()) throw new Error("Invalid month. Use YYYY-MM.");

const year = dateMoment.format("YYYY");  
const monthNum = dateMoment.format("MM");  
const monthName = dateMoment.format("MMMM");  
const quarter = dateMoment.quarter();

// Auto-rename  
await tp.file.rename(`${year}-M${monthNum}-${monthName}`);

// Auto-move  
await tp.file.move(`13 - PRIVATE/1302 - Journal/${year}/Monthly Notes/${year}-M${monthNum}-${monthName}`);

tR += `---
year_num: ${year}  
Year_Link: "[[13 - PRIVATE/1302 - Journal/${year}/${year}]]"  
quarter_num: ${quarter}  
Quarterly_Link: "[[13 - PRIVATE/1302 - Journal/${year}/Quarterly Notes/${year}-Q${quarter}]]"  
month_num: ${monthNum}
Monthly_Link: "[[13 - PRIVATE/1302 - Journal/${year}/Monthly Notes/${year}-M${monthNum}-${monthName}]]"
aliases:
  - "${monthName} ${year}"  
tags:
  - monthly-note  
monthly_avg_sleep_time: "Xh Ym"  
monthly_avg_wakeup_time: "Xh Ym"  
monthly_avg_sleep_duration: "Xh Ym"  
monthly_pomos: 0  
monthly_pomo_duration: "0h 0m"
---
`;

// Breadcrumbs  
tR += `**YEAR:** [[13 - PRIVATE/1302 - Journal/${year}/${year}|${year}]] • **QUARTER:** [[13 - PRIVATE/1302 - Journal/${year}/Quarterly Notes/${year}-Q${quarter}|${year}-Q${quarter}]] • **MONTH:** [[13 - PRIVATE/1302 - Journal/${year}/Monthly Notes/${year}-M${monthNum}-${monthName}|${monthName}]]\n\n`;  
%>
```dataviewjs
// Weekly Notes for {MonthName}, {Year}
const year = dv.current().year_num;
const monthNum = dv.current().month_num;
const monthName = moment(dv.current().file.name, "YYYY-[M]MM-MMMM").format("MMMM");

dv.paragraph(`## Weekly Notes for ${monthName}, ${year}`);

const weeklyNotesPath = `13 - PRIVATE/1302 - Journal/${year}/Weekly Notes`;
const weeklyNotes = dv.pages(`"${weeklyNotesPath}"`).where(w => w.month_num == monthNum);

if (weeklyNotes.length > 0) {
    weeklyNotes
        .sort(w => w.week_num)
        .forEach(weekNote => {
            dv.paragraph(`- [[${weekNote.file.path}|${weekNote.file.name.replace(/\.md$/, "")}]]`);
        });
} else {
    dv.paragraph(`No weekly notes found for ${monthName}, ${year}.`);
}
```

### TO-DO:
- **BASE 3**:
    - [ ] 
    - [ ] 
    - [ ] 
- Others:
    - [ ] 
    - [ ] 

### THE 30 min of Nothing
- [ ] 

---

# Journal Entry:

## Morning ME:
**07:00 AM - 08:00 AM**
- 

## Focus Work ME:
==**08:00 AM - 02:00 PM**==
#### **BLOCK 1**:
- ==08:00 AM - 10:00 AM==
    - [ ] P1:
    - [ ] P2:
    - [ ] P3:
    - [ ] P4:

#### **Block 2**:
- ==11:00 AM - 02:00 PM==
    - [ ] P1:
    - [ ] P2:
    - [ ] P3:
    - [ ] P4:
    - [ ] P5:

## Relaxed Work ME:
==**02:00 PM - 04:30 PM**==
#### **Block 3**:
- [ ] P1: 
- [ ] P2:
- [ ] P3:

## ME 4 ME:
==**04:30 PM - 06:30 PM**==
- **Physical Activity**:
- **Hobby**:
- **Connect/Surf**:

## Sleep ME:
==**07:30 PM - 09:30 PM**==
- **Music**:
- **ShowTime**:
- **Reading**:

## Prominent Thought Leech
1. 
2. 
3. 

## **My THOUGHTS**:
- _

---

```dataviewjs
const year = dv.current().year_num;
const monthNum = dv.current().month_num;
const monthName = moment().month(monthNum - 1).format("MMMM");

const dailyNotesPath = `13 - PRIVATE/1302 - Journal/${year}/010101 - Daily Notes`;

// This now filters by BOTH year and month for maximum robustness.
const dailyInMonth = dv.pages(`"${dailyNotesPath}"`)
    .where(d => d.year_num == year && d.month_num == monthNum);

let totalPomos = 0;
let wakeupTimes = [];
let sleepTimes = [];
let sleepDurations = []; // This will be an array of total minutes per day

// Collect data directly from daily notes
for (let day of dailyInMonth) {
    // Sum Pomos
    const pomos = parseInt(day.pomos ?? 0);
    if (!isNaN(pomos)) {
        totalPomos += pomos;
    }

    // Collect times for averaging
    if (day.wakeup_time) wakeupTimes.push(day.wakeup_time);
    if (day.sleep_time) sleepTimes.push(day.sleep_time);

    // --- ROBUST SLEEP DURATION PARSING ---
    if (day.sleep_duration) {
        const durStr = String(day.sleep_duration);
        let totalMinutes = 0;

        // Independently find hours and minutes from the string
        const hourMatch = durStr.match(/(\d+)\s*h/i);
        const minMatch = durStr.match(/(\d+)\s*m/i);

        if (hourMatch) {
            totalMinutes += parseInt(hourMatch[1]) * 60;
        }
        if (minMatch) {
            totalMinutes += parseInt(minMatch[1]);
        }
        
        // Only add to the array if a valid duration was found
        if (totalMinutes > 0) {
            sleepDurations.push(totalMinutes);
        }
    }
}

// --- HELPER FUNCTIONS ---

function avgTime(times) {
    if (!times.length) return "No data";
    const totalMinutes = times.reduce((acc, t) => {
        const m = moment(t, ["h:mm A", "H:mm"]);
        return acc + (m.hours() * 60 + m.minutes());
    }, 0);
    const avg = totalMinutes / times.length;
    const h = Math.floor(avg / 60);
    const m = Math.floor(avg % 60);
    return moment({ hour: h, minute: m }).format("h:mm A");
}

function avgDuration(minArr) {
    if (!minArr.length) return "No data";
    const avg = minArr.reduce((a, b) => a + b, 0) / minArr.length;
    const h = Math.floor(avg / 60);
    const m = Math.floor(avg % 60);
    return `${h}h ${m}m`;
}

function formatPomoDuration(pomoCount) {
    const totalMinutes = pomoCount * 25;
    const h = Math.floor(totalMinutes / 60);
    const m = totalMinutes % 60;
    return `${h}h ${m}m`;
}

// --- DISPLAY RESULTS ---

dv.paragraph(`**Monthly Summary for ${monthName}, ${year}**`);
dv.paragraph(`- **Average Sleep Time:** ${avgTime(sleepTimes)}`);
dv.paragraph(`- **Average Wakeup Time:** ${avgTime(wakeupTimes)}`);
dv.paragraph(`- **Average Sleep Duration:** ${avgDuration(sleepDurations)}`);
dv.paragraph(`- **Total Pomos:** ${totalPomos}`);
dv.paragraph(`- **Total Pomodoro Duration:** ${formatPomoDuration(totalPomos)}`);
```
