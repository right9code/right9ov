<%*
/* 1) Prompt date and times */
const dateInput = await tp.system.prompt("Enter date (e.g., 2025-08-11):", moment().format("YYYY-MM-DD")) || moment().format("YYYY-MM-DD");
if (!moment(dateInput, "YYYY-MM-DD", true).isValid()) throw new Error("Invalid date. Use YYYY-MM-DD.");

let sleepTime   = await tp.system.prompt("Sleep time (e.g., 10:00 PM):", "10:00 PM") || "10:00 PM";
let wakeupTime  = await tp.system.prompt("Wakeup time (e.g., 6:00 AM):", "6:00 AM") || "6:00 AM";
let energyLevel = await tp.system.prompt("Energy level (1-10):", "6") || "6";

/* 2) Time helpers and duration */
function ampmTo24(timeStr) {
  const [time, period] = timeStr.trim().split(/\s+/);
  let [h, m] = time.split(":").map(Number);
  if (period?.toUpperCase() === "PM" && h !== 12) h += 12;
  if (period?.toUpperCase() === "AM" && h === 12) h = 0;
  return { hours: h, minutes: m };
}

const st = ampmTo24(sleepTime);
const wt = ampmTo24(wakeupTime);
const sleepDate = new Date(2000, 0, 1, st.hours, st.minutes);
let wakeDate =   new Date(2000, 0, 1, wt.hours, wt.minutes);
if (wakeDate < sleepDate) wakeDate.setDate(wakeDate.getDate() + 1);
const diff = wakeDate - sleepDate;
const durationH = Math.floor(diff / 3600000);
const durationM = Math.floor((diff % 3600000) / 60000);
const sleepDuration = `${durationH}h ${durationM}m`;

/* 3) Date components via moment (avoid tp.date cache/minutes bug) */
const m = moment(dateInput, "YYYY-MM-DD");
const year       = m.format("YYYY");
const monthNum   = m.format("MM");
const month      = m.format("MMMM");
const dayNum     = m.format("DD");
const weekNum    = m.format("ww");
const quarter    = m.quarter();
const weekday    = m.format("dddd");
const weekdayNum = m.isoWeekday();

/* 4) Compute final filename and destination path */
const newName = `${year}-${monthNum}-${dayNum}`;
const destPath = `13 - PRIVATE/1302 - Journal/${year}/Daily Notes/${newName}`;

/* 5) Ensure destination folders exist (Templater v1.25+ required for exists/mkdir) */
if (!(await tp.file.exists(`13 - PRIVATE/1302 - Journal/${year}/Daily Notes`))) {
  await app.vault.createFolder(`13 - PRIVATE/1302 - Journal/${year}/Daily Notes`);
}

/* 6) Rename first, then small delay, then move to prevent race conditions */
await tp.file.rename(newName);
await new Promise(r => setTimeout(r, 200)); // mitigate timing issues on fresh notes
await tp.file.move(destPath);

/* 7) Build frontmatter string safely; quote strings with spaces/colons */
const Year_Link      = `[[13 - PRIVATE/1302 - Journal/${year}/${year}]]`;
const Quarterly_Link = `[[13 - PRIVATE/1302 - Journal/${year}/Quarterly Notes/${year}-Q${quarter}]]`;
const Monthly_Link   = `[[13 - PRIVATE/1302 - Journal/${year}/Monthly Notes/${year}-M${monthNum}-${month}]]`;
const Week_Link      = `[[13 - PRIVATE/1302 - Journal/${year}/Weekly Notes/${year}-W${weekNum}]]`;
const Date_Link      = `[[13 - PRIVATE/1302 - Journal/${year}/Daily Notes/${newName}|${dateInput}]]`;
const Weekday_Link   = `[[13 - PRIVATE/1302 - Journal/Weekdays/${weekdayNum} - ${weekday}|${weekday}]]`;

const fm = `---
year_num: ${year}
Year_Link: "${Year_Link}"
quarter_num: ${quarter}
Quarterly_Link: "${Quarterly_Link}"
month_num: ${monthNum}
Monthly_Link: "${Monthly_Link}"
week_num: ${weekNum}
Week_Link: "${Week_Link}"
date: ${dateInput}
Date_Link: "${Date_Link}"
weekday: "${weekday}"
Weekday_Link: "${Weekday_Link}"
Day_type:
  - "[[LineDAY]]"
  - "[[ArcDAY]]"
  - "[[SwayDAY]]"
aliases:
  - "${weekday}, ${month} ${dayNum} ${year}"
tags:
  - daily-note
sleep_time: "${sleepTime}"
wakeup_time: "${wakeupTime}"
energy_lvl: ${Number(energyLevel)}
sleep_duration: "${sleepDuration}"
pomos: 0
pomo_duration: "0h 0m"
---`;

tR += fm + "\n";

/* 8) Breadcrumb (after frontmatter) */
tR += `**YEAR:** [[13 - PRIVATE/1302 - Journal/${year}/${year}|${year}]] • **QUARTER:** [[13 - PRIVATE/1302 - Journal/${year}/Quarterly Notes/${year}-Q${quarter}|${year}-Q${quarter}]] • **MONTH:** [[13 - PRIVATE/1302 - Journal/${year}/Monthly Notes/${year}-M${monthNum}-${month}|${month}]] • **WEEK:** [[13 - PRIVATE/1302 - Journal/${year}/Weekly Notes/${year}-W${weekNum}|${year}-W${weekNum}]] • **DATE:** [[13 - PRIVATE/1302 - Journal/${year}/Daily Notes/${newName}|${dateInput}]] • **DAY:** [[13 - PRIVATE/1302 - Journal/Weekdays/${weekdayNum} - ${weekday}|${weekday}]]\n\n`;
%>

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
# JOURNAL Entry:

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

