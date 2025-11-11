<%*
// Prompt for year in format "YYYY"
let yearInput = await tp.system.prompt("Enter year (e.g., 2025):");
if (!yearInput) yearInput = tp.date.now("YYYY"); // Fallback to the current year

const year = yearInput;

// AUTO-RENAME THE FILE
await tp.file.rename(`${year}`);

// AUTO-MOVE THE FILE
await tp.file.move(`01 - Journal/${year}/${year}`);

tR += `---
year_num: ${year}
Year_Link: "[[01 - Journal/${year}/${year}]]"
aliases:
  - "${year}"
tags:
  - yearly-note
yearly_avg_sleep_time: "Xh Ym"
yearly_avg_wakeup_time: "Xh Ym"
yearly_avg_sleep_duration: "Xh Ym"
yearly_pomos: 0
yearly_pomo_duration: "0h 0m"
---

**YEAR:** [[01 - Journal/${year}/${year}|${year}]]

`;
%>
```dataviewjs
const year = dv.current().year_num;

const quarterlyNotesPath = `01 - Journal/${year}/010104 - Quarterly Notes`;

// This block finds and lists the quarterly notes for this year.
const quarterlyNotesInYear = dv.pages(`"${quarterlyNotesPath}"`)
    .where(q => q.year_num == year);

dv.paragraph(`## Quarterly Notes for ${year}`);

if (quarterlyNotesInYear.length > 0) {
    quarterlyNotesInYear
        .sort(q => q.quarter_num) // Sort by quarter number
        .forEach(qNote => {
            dv.paragraph(`- [[${qNote.file.path}|${qNote.file.name.replace(/\.md$/, "")}]]`);
        });
} else {
    dv.paragraph("No quarterly notes found for this year.");
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

const dailyNotesPath = `01 - Journal/${year}/010101 - Daily Notes`;

// This block calculates the yearly summary from all daily notes in this year.
const dailyInYear = dv.pages(`"${dailyNotesPath}"`)
    .where(d => d.year_num == year);

let totalPomos = 0;
let wakeupTimes = [];
let sleepTimes = [];
let sleepDurations = [];

for (let day of dailyInYear) {
    const pomos = parseInt(day.pomos ?? 0);
    if (!isNaN(pomos)) {
        totalPomos += pomos;
    }

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

// --- HELPER FUNCTIONS (Consistent with all other templates) ---

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

dv.paragraph(`**Yearly Summary for ${year}**`);
dv.paragraph(`- **Average Sleep Time:** ${avgTime(sleepTimes)}`);
dv.paragraph(`- **Average Wakeup Time:** ${avgTime(wakeupTimes)}`);
dv.paragraph(`- **Average Sleep Duration:** ${avgDuration(sleepDurations)}`);
dv.paragraph(`- **Total Pomos:** ${totalPomos}`);
dv.paragraph(`- **Total Pomodoro Duration:** ${formatPomoDuration(totalPomos)}`);
```
