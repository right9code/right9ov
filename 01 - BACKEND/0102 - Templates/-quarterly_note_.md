<%*
// Prompt for quarter in format "YYYY-Qq"
let quarterInput = await tp.system.prompt("Enter quarter (e.g., 2025-Q2):");
if (!quarterInput) quarterInput = tp.date.now("YYYY-[Q]Q").replace("[Q]", "Q"); // Fallback to current quarter

const [year, quarterNum] = quarterInput.split("-Q");

// AUTO-RENAME THE FILE
await tp.file.rename(`${year}-Q${quarterNum}`);

// AUTO-MOVE THE FILE
await tp.file.move(`13 - PRIVATE/1302 - Journal/${year}/Quarterly Notes/${year}-Q${quarterNum}`);

tR += `---
year_num: ${year}
Year_Link: "[[13 - PRIVATE/1302 - Journal/${year}/${year}]]"
quarter_num: ${quarterNum}
Quarterly_Link: "[[13 - PRIVATE/1302 - Journal/${year}/04 - Quarterly Notes/${year}-Q${quarterNum}]]"
aliases:
  - "Q${quarterNum} ${year}"
tags:
  - quarterly-note
quarterly_avg_sleep_time: "Xh Ym"
quarterly_avg_wakeup_time: "Xh Ym"
quarterly_avg_sleep_duration: "Xh Ym"
quarterly_pomos: 0
quarterly_pomo_duration: "0h 0m"
---

**YEAR:** [[13 - PRIVATE/1302 - Journal/${year}/${year}|${year}]] • **QUARTER:** [[13 - PRIVATE/1302 - Journal/${year}/Quarterly Notes/${year}-Q${quarterNum}|${year}-Q${quarterNum}]]

`;
%>
```dataviewjs
const year = dv.current().year_num;
const quarterNum = dv.current().quarter_num;

const monthlyNotesPath = `13 - PRIVATE/1302 - Journal/${year}/Monthly Notes`;

// This block finds and lists the monthly notes for this quarter.
const monthlyNotesInQuarter = dv.pages(`"${monthlyNotesPath}"`)
    .where(month => month.year_num == year && month.quarter_num == quarterNum);

dv.paragraph(`## Monthly Notes for ${dv.current().aliases[0]}`);

if (monthlyNotesInQuarter.length > 0) {
    monthlyNotesInQuarter
        .sort(month => month.month_num) // Sort by month number
        .forEach(monthNote => {
            dv.paragraph(`- [[${monthNote.file.path}|${monthNote.file.name.replace(/\.md$/, "")}]]`);
        });
} else {
    dv.paragraph("No monthly notes found for this quarter.");
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
const quarterNum = dv.current().quarter_num;

const dailyNotesPath = `13 - PRIVATE/1302 - Journal/${year}/Daily Notes`;

// This block calculates the quarterly summary from all the relevant daily notes.
const dailyInQuarter = dv.pages(`"${dailyNotesPath}"`)
    .where(d => d.year_num == year && d.quarter_num == quarterNum);

let totalPomos = 0;
let wakeupTimes = [];
let sleepTimes = [];
let sleepDurations = [];

for (let day of dailyInQuarter) {
    const pomos = parseInt(day.pomos ?? 0);
    if (!isNaN(pomos)) {
        totalPomos += pomos;
    }

    if (day.wakeup_time) wakeupTimes.push(day.wakeup_time);
    if (day.sleep_time) sleepTimes.push(day.sleep_time);

    if (day.sleep_duration) {
        const durStr = String(day.sleep_duration);
        let totalMinutes = 0;
        const hourMatch = durStr.match(/(\d+)\s*h/i);
        const minMatch = durStr.match(/(\d+)\s*m/i);
        
        // --- THIS IS THE CORRECTED LOGIC ---
        if (hourMatch) {
            totalMinutes += parseInt(hourMatch[1]) * 60;
        }
        if (minMatch) {
            totalMinutes += parseInt(minMatch[1]);
        }
        
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

// --- DISPLAY RESULTS (Corrected Order) ---

dv.paragraph(`**Quarterly Summary for ${dv.current().aliases[0]}**`);
dv.paragraph(`- **Average Wakeup Time:** ${avgTime(wakeupTimes)}`);
dv.paragraph(`- **Average Sleep Time:** ${avgTime(sleepTimes)}`);
dv.paragraph(`- **Average Sleep Duration:** ${avgDuration(sleepDurations)}`);
dv.paragraph(`- **Total Pomos:** ${totalPomos}`);
dv.paragraph(`- **Total Pomodoro Duration:** ${formatPomoDuration(totalPomos)}`);
```
