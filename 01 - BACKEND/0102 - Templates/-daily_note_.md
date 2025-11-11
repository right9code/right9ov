<%*
// Prompt for date in format "YYYY-MM-DD"
let dateInput = await tp.system.prompt("Enter date (e.g., 2025-08-11):", tp.date.now("YYYY-MM-DD"));
const dateMoment = moment(dateInput, "YYYY-MM-DD");
if (!dateMoment.isValid()) throw new Error("Invalid date. Use YYYY-MM-DD.");

// Prompt for sleep time, wakeup time, energy level with fallbacks
let sleepTime   = await tp.system.prompt("Sleep time (e.g., 10:00 PM):", "10:00 PM")   || "10:00 PM";
let wakeupTime  = await tp.system.prompt("Wakeup time (e.g., 6:00 AM):", "6:00 AM")     || "6:00 AM";
let energyLevel = await tp.system.prompt("Energy level (1-10):", "6")                   || "6";

// Helper to convert AM/PM to 24-hour
function ampmTo24(timeStr) {
  const [time, period] = timeStr.split(" ");
  let [h, m] = time.split(":").map(Number);
  if (period === "PM" && h !== 12) h += 12;
  if (period === "AM" && h === 12) h = 0;
  return { hours: h, minutes: m };
}

// Calculate sleep duration
const st = ampmTo24(sleepTime), wt = ampmTo24(wakeupTime);
const sleepDate = new Date(2000,0,1, st.hours, st.minutes);
let wakeDate =   new Date(2000,0,1, wt.hours,  wt.minutes);
if (wakeDate < sleepDate) wakeDate.setDate(wakeDate.getDate()+1);
const diff = wakeDate - sleepDate;
const durationH = Math.floor(diff / 3600000);
const durationM = Math.floor((diff % 3600000) / 60000);
const sleepDuration = `${durationH}h ${durationM}m`;

// Extract components
const year     = dateMoment.format("YYYY");
const monthNum = dateMoment.format("MM");
const month    = dateMoment.format("MMMM");
const dayNum   = dateMoment.format("DD");
const weekNum  = dateMoment.format("ww");
const quarter  = dateMoment.quarter();
const weekday  = dateMoment.format("dddd");
const weekdayNum = dateMoment.isoWeekday();

// Auto-rename & move
await tp.file.rename(`${year}-${monthNum}-${dayNum}`);
await tp.file.move(`13 - PRIVATE/1302 - Journal/${year}/Daily Notes/${year}-${monthNum}-${dayNum}`);

// Emit frontmatter
tR += `---
year_num: ${year}
Year_Link: "[[13 - PRIVATE/1302 - Journal/${year}/${year}]]"
quarter_num: ${quarter}
Quarterly_Link: "[[13 - PRIVATE/1302 - Journal/${year}/04 - Quarterly Notes/${year}-Q${quarter}]]"
month_num: ${monthNum}
Monthly_Link: "[[13 - PRIVATE/1302 - Journal/${year}/03 - Monthly Notes/${year}-M${monthNum}-${month}]]"
week_num: ${weekNum}
Week_Link: "[[13 - PRIVATE/1302 - Journal/${year}/02 - Weekly Notes/${year}-W${weekNum}]]"
date: ${dateInput}
Date_Link: "[[13 - PRIVATE/1302 - Journal/${year}/Daily Notes/${year}-${monthNum}-${dayNum}]]"
weekday: "${weekday}"
Weekday_Link: "[[13 - PRIVATE/1302 - Journal/Weekdays/${weekdayNum} - ${weekday}|${weekday}]]"
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
energy_lvl: ${energyLevel}
sleep_duration: "${sleepDuration}"
pomos: 0
pomo_duration: "0h 0m"
---
`;

// Breadcrumb line
tR += `**YEAR:** [[13 - PRIVATE/1302 - Journal/${year}/${year}|${year}]] • **QUARTER:** [[13 - PRIVATE/1302 - Journal/${year}/010104 - Quarterly Notes/${year}-Q${quarter}|${year}-Q${quarter}]] • **MONTH:** [[13 - PRIVATE/1302 - Journal/${year}/010103 - Monthly Notes/${year}-M${monthNum}-${month}|${month}]] • **WEEK:** [[13 - PRIVATE/1302 - Journal/${year}/010102 - Weekly Notes/${year}-W${weekNum}|${year}-W${weekNum}]] • **DATE:** [[13 - PRIVATE/1302 - Journal/${year}/0101Daily Notes/${year}-${monthNum}-${dayNum}|${dateInput}]] • **DAY:** [[13 - PRIVATE/1302 - Journal/Weekdays/${weekdayNum} - ${weekday}|${weekday}]]\n\n`;
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



---

```dataviewjs
const pomos = dv.current().pomos ?? 0;
const totalMinutes = pomos * 25;
const hours = Math.floor(totalMinutes / 60);
const mins = totalMinutes % 60;
const pomo_duration = `${hours}h ${mins}m`;

dv.paragraph(`**Total Pomos Today:** ${pomos}`);
dv.paragraph(`**Total Pomodoro Duration Today:** ${pomo_duration}`);
```
