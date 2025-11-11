<%*
// Prompt for date in format "YYYY-MM-DD"
let dateInput = await tp.system.prompt("Enter date (e.g., 2025-08-11):", tp.date.now("YYYY-MM-DD"));
const dateMoment = moment(dateInput, "YYYY-MM-DD");
if (!dateMoment.isValid()) throw new Error("Invalid date. Use YYYY-MM-DD.");

// Prompts
let sleepTime   = await tp.system.prompt("Sleep time (e.g., 10:00 PM):", "10:00 PM")   || "10:00 PM";
let wakeupTime  = await tp.system.prompt("Wakeup time (e.g., 6:00 AM):", "6:00 AM")     || "6:00 AM";
let energyLevel = await tp.system.prompt("Energy level (1-10):", "6")                   || "6";

// AM/PM → 24h
function ampmTo24(timeStr) {
  const [time, period] = timeStr.split(" ");
  let [h, m] = time.split(":").map(Number);
  if (period === "PM" && h !== 12) h += 12;
  if (period === "AM" && h === 12) h = 0;
  return { hours: h, minutes: m };
}

// Sleep duration
const st = ampmTo24(sleepTime), wt = ampmTo24(wakeupTime);
const sleepDate = new Date(2000,0,1, st.hours, st.minutes);
let wakeDate =   new Date(2000,0,1, wt.hours,  wt.minutes);
if (wakeDate < sleepDate) wakeDate.setDate(wakeDate.getDate()+1);
const diff = wakeDate - sleepDate;
const durationH = Math.floor(diff / 3600000);
const durationM = Math.floor((diff % 3600000) / 60000);
const sleepDuration = `${durationH}h ${durationM}m`;

// Date parts
const year       = dateMoment.format("YYYY");
const monthNum   = dateMoment.format("MM");
const monthName  = dateMoment.format("MMMM");
const dayNum     = dateMoment.format("DD");
const weekNum    = dateMoment.format("ww");
const quarterNum = dateMoment.quarter();
const weekday    = dateMoment.format("dddd");
const weekdayNum = dateMoment.isoWeekday();

// Canonical paths
const JOURNAL_ROOT   = "13 - PRIVATE/1302 - Journal";
const YEAR_DIR       = `${JOURNAL_ROOT}/${year}`;
const DAILY_DIR      = `${YEAR_DIR}/01 - Daily Notes`;
const WEEKLY_DIR     = `${YEAR_DIR}/02 - Weekly Notes`;
const MONTHLY_DIR    = `${YEAR_DIR}/03 - Monthy Notes`; // keep current spelling
const QUARTERLY_DIR  = `${YEAR_DIR}/04 - Quarterly Notes`;

// File names
const yearFile         = `${year}`;
const dailyFile        = `${year}-${monthNum}-${dayNum}`;
const weeklyFile       = `${year}-W${weekNum}`;
const monthlyFile      = `${year}-${monthNum}`;         // standardized to YYYY-MM
const quarterlyFile    = `${year}-Q${quarterNum}`;

// Move current note
await tp.file.rename(dailyFile);
await tp.file.move(`${DAILY_DIR}/${dailyFile}`);

// Frontmatter
tR += `---
year_num: ${year}
Year_Link: "[[${YEAR_DIR}/${yearFile}|${year}]]"
quarter_num: ${quarterNum}
Quarterly_Link: "[[${QUARTERLY_DIR}/${quarterlyFile}|${year}-Q${quarterNum}]]"
month_num: ${monthNum}
Monthly_Link: "[[${MONTHLY_DIR}/${monthlyFile}|${year}-${monthNum}]]"
week_num: ${weekNum}
Week_Link: "[[${WEEKLY_DIR}/${weeklyFile}|${year}-W${weekNum}]]"
date: ${dateInput}
Date_Link: "[[${DAILY_DIR}/${dailyFile}|${dateInput}]]"
weekday: "${weekday}"
Weekday_Link: "[[01 - BACKEND/0104 - Bases/Weekdays/${weekdayNum} - ${weekday}|${weekday}]]"
Day_type:
  - "[[LineDAY]]"
  - "[[ArcDAY]]"
  - "[[SwayDAY]]"
aliases:
  - "${weekday}, ${monthName} ${dayNum} ${year}"
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

// Breadcrumbs
tR += `**YEAR:** [[${YEAR_DIR}/${yearFile}|${year}]] • **QUARTER:** [[${QUARTERLY_DIR}/${quarterlyFile}|${year}-Q${quarterNum}]] • **MONTH:** [[${MONTHLY_DIR}/${monthlyFile}|${year}-${monthNum}]] • **WEEK:** [[${WEEKLY_DIR}/${weeklyFile}|${year}-W${weekNum}]] • **DATE:** [[${DAILY_DIR}/${dailyFile}|${dateInput}]] • **DAY:** [[01 - BACKEND/0104 - Bases/Weekdays/${weekdayNum} - ${weekday}|${weekday}]]\n\n`;
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

