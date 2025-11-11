<%*
// Prompt for week in format "YYYY-Www"
let weekInput = await tp.system.prompt("Enter week (e.g., 2025-W25):");
if (!weekInput) weekInput = tp.date.now("YYYY-[W]ww");

const [year, weekNum] = weekInput.split("-W");

// AUTO-RENAME
await tp.file.rename(`${year}-W${weekNum}`);

// Week details
const weekMoment = moment().year(year).isoWeek(parseInt(weekNum));
const quarter = weekMoment.quarter();
const monthNum = weekMoment.format("MM");
const monthName = weekMoment.format("MMMM");

// AUTO-MOVE
await tp.file.move(`13 - PRIVATE/1302 - Journal/${year}/Weekly Notes/${year}-W${weekNum}`);

// YAML
tR += `---
year_num: ${year}
Year_Link: "[[01 - BACKEND/0105 - Excalidraw/${year}/${year}]]"
quarter_num: ${quarter}
Quarterly_Link: "[[13 - PRIVATE/1302 - Journal/${year}/04 - Quarterly Notes/${year}-Q${quarter}]]"
month_num: ${monthNum}
Monthly_Link: "[[13 - PRIVATE/1302 - Journal/${year}/03 - Monthly Notes/${year}-M${monthNum}-${monthName}]]"
week_num: ${weekNum}
Week_Link: "[[13 - PRIVATE/1302 - Journal/${year}/02 - Weekly Notes/${year}-W${weekNum}]]"
aliases:
  - "Week ${weekNum}, ${monthName} ${year}"
tags:
  - weekly-note
weekly_avg_sleep_time: "Xh Ym"
weekly_avg_wakeup_time: "Xh Ym"
weekly_avg_sleep_duration: "Xh Ym"
weekly_pomos: 0
weekly_pomo_duration: "0h 0m"
---
`;

// Breadcrumb line
tR += `**YEAR:** [[13 - PRIVATE/1302 - Journal/${year}/${year}|${year}]] • **QUARTER:** [[13 - PRIVATE/1302 - Journal/${year}/Quarterly Notes/${year}-Q${quarter}|${year}-Q${quarter}]] • **MONTH:** [[13 - PRIVATE/1302 - Journal/${year}/Monthly Notes/${year}-M${monthNum}-${monthName}|${monthName}]] • **WEEK:** [[13 - PRIVATE/1302 - Journal/${year}/Weekly Notes/${year}-W${weekNum}|${year}-W${weekNum}]]\n\n`;
%>
```dataviewjs
const year = dv.current().year_num;  
const weekNum = dv.current().week_num;  
const dailyNotesPath = `13 - PRIVATE/1302 - Journal/${year}/010101 - Daily Notes`;  

// More robust filter: checks year AND week_num
const dailyNotesInWeek = dv.pages(`"${dailyNotesPath}"`)
    .where(day => day.year_num == year && day.week_num == weekNum);

dv.paragraph(`## **Daily Notes for Week ${weekNum}**`);  
if (dailyNotesInWeek.length > 0) {  
    dailyNotesInWeek
        .sort(day => day.file.name)
        .forEach(dayNote => {
            dv.paragraph(`- [[${dayNote.file.path}|${dayNote.file.name.replace(/\.md$/, "")}]]`);  
        });
} else {  
    dv.paragraph("No daily notes found for this week.");  
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

---

# Journal Entry:

## Morning ME:
==**07:00 AM – 08:00 AM**==  
-  

## Focus Work ME:
==**08:00 AM – 02:00 PM**==  
#### **BLOCK 1**:
- ==**08:00 AM – 10:00 AM**==
	- [ ] P1:   
	- [ ] P2:   
	- [ ] P3:   
	- [ ] P4:   

#### **BLOCK 2**: 
- ==**11:00 AM – 02:00 PM**==
	- [ ] P1:   
	- [ ] P2:   
	- [ ] P3:   
	- [ ] P4:   
	- [ ] P5:   

## Relaxed Work ME:
==**02:00 PM – 04:30 PM**== 
#### **BLOCK 3**:
- [ ] P1:  
- [ ] P2:  
- [ ] P3:  

## ME 4 ME:
==**04:30 PM – 06:30 PM**==  
- **Physical Activity**:   
- **Hobby**:   
- **Connect/Surf**:   

## Sleep ME:
==**07:30 PM – 09:30 PM**==  
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
const weekNum = dv.current().week_num;

const dailyNotesPath = `13 - PRIVATE/1302 - Journal/${year}/010101 - Daily Notes`;

// More robust filter: checks year AND week_num
const dailyNotesInWeek = dv.pages(`"${dailyNotesPath}"`)
    .where(day => day.year_num == year && day.week_num == weekNum);

let totalPomos = 0;
let wakeupTimes = [];
let sleepTimes = [];
let sleepDurations = []; // This will be an array of total minutes per day

for (let day of dailyNotesInWeek) {
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

// --- DISPLAY RESULTS (Consistent Order) ---

dv.paragraph(`**Weekly Summary for Week ${weekNum}**`);
dv.paragraph(`- **Average Sleep Time:** ${avgTime(sleepTimes)}`);
dv.paragraph(`- **Average Wakeup Time:** ${avgTime(wakeupTimes)}`);
dv.paragraph(`- **Average Sleep Duration:** ${avgDuration(sleepDurations)}`);
dv.paragraph(`- **Total Pomos:** ${totalPomos}`);
dv.paragraph(`- **Total Pomodoro Duration:** ${formatPomoDuration(totalPomos)}`);
```
