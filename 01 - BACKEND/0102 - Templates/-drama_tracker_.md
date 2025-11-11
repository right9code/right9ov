<%*
// --- CONFIGURATION ---
const apiKey = "e0a86214a4949afb1d2a0beddde2a203";
const targetFolder = "/97 - PRIVATE/9701 - CC/03 - Dramas/";
const defaultCoverUrl = "https://www.themoviedb.org/assets/2/v4/glyphicons/basic/glyphicons-basic-4-user-grey-d8fe957375e70239d6abdd5492136659632908079dd20405d225TCb85E94f094.svg";

const notice = (msg) => new Notice(msg, 6000);

if (!apiKey || apiKey.trim() === "") {
    notice("❌ TMDb API key is missing. Please add it to the template configuration.");
    return;
}

let title, coverUrl, synopsis, genres, allSeasonsData = [];
let isManual = false;

// 1. Search prompt with icon
const query = await tp.system.prompt("🎭 Enter the drama title to search for:");
if (!query) {
    notice("❌ No title entered. Template cancelled.");
    return;
}

notice(`🔍 Searching for "${query}" on TMDb...`);
let searchResults;
try {
    const searchResponse = await requestUrl(`https://api.themoviedb.org/3/search/tv?api_key=${apiKey}&query=${encodeURIComponent(query)}`);
    searchResults = searchResponse.json.results;
} catch (error) {
    notice("⚠️ Error connecting to TMDb API. Switching to manual entry.");
    isManual = true;
}

if (!isManual) {
    if (searchResults && searchResults.length > 0) {
        const manualEntryText = "✏️ --- My Drama Isn't Listed (Enter Manually) ---";
        const manualEntrySentinel = { id: "MANUAL_ENTRY", name: "Manual" };

        const dramaChoices = [manualEntryText, ...searchResults.map(d => {
            const year = d.first_air_date ? `(${d.first_air_date.substring(0, 4)})` : "";
            return `🎬 ${d.name} ${year}`;
        })];
        
        const dramaData = [manualEntrySentinel, ...searchResults];
        const selectedDrama = await tp.system.suggester(dramaChoices, dramaData, true, "🎭 Select the correct drama, or choose manual entry:");

        if (!selectedDrama) {
            notice("❌ Selection cancelled. Switching to manual entry.");
            isManual = true;
        } else if (selectedDrama.id === "MANUAL_ENTRY") {
            notice("✏️ Switching to manual entry.");
            isManual = true;
        } else {
            notice(`📺 Fetching details for ${selectedDrama.name}...`);
            const detailsResponse = await requestUrl(`https://api.themoviedb.org/3/tv/${selectedDrama.id}?api_key=${apiKey}`);
            const details = detailsResponse.json;
            
            title = details.name;
            coverUrl = details.poster_path ? `https://image.tmdb.org/t/p/w500${details.poster_path}` : defaultCoverUrl;
            synopsis = details.overview || "No synopsis available.";
            genres = details.genres.map(g => g.name);
            allSeasonsData = details.seasons;
        }
    } else {
        notice("❌ Drama not found online. Switching to manual entry.");
        isManual = true;
    }
}

// Manual entry with icons
if (isManual) {
    title = await tp.system.prompt("🎬 Title:", query);
    if (!title) { notice("❌ No title entered. Template cancelled."); return; }
    
    const coverUrlInput = await tp.system.prompt("🖼️ Cover Image URL (leave blank for default):");
    coverUrl = coverUrlInput.trim() === "" ? defaultCoverUrl : coverUrlInput;
    
    synopsis = await tp.system.prompt("📝 Synopsis (can be multiline):") || "No synopsis available.";
    
    const genreInput = await tp.system.prompt("🏷️ Genre(s), comma-separated:");
    genres = genreInput ? genreInput.split(',').map(g => g.trim()) : [];
    
    const totalSeasons = parseInt(await tp.system.prompt("📺 How many seasons?")) || 1;
    for (let s = 1; s <= totalSeasons; s++) {
        const numEpisodes = parseInt(await tp.system.prompt(`📋 How many episodes in Season ${s}?`)) || 1;
        allSeasonsData.push({ name: `Season ${s}`, episode_count: numEpisodes });
    }
}

// Status with icons
const userStatusId = await tp.system.suggester(
    ["🎭 Currently Watching", "✅ Completed", "⏸️ On-Hold", "❌ Dropped", "📋 Plan to Watch"], 
    ["ongoing", "finished", "onhold", "dropped", "queued"], 
    false, "📊 What is your status for this drama?"
);

const rating = await tp.system.prompt("⭐ Your rating (e.g., 8/10, or leave blank):");

// File generation (same as yours but with forward episode order)
const yaml = `---
type: asian_drama
title: "${title}"
cover_url: "${coverUrl}"
status: ${userStatusId}
rating: ${rating ? `"${rating}"` : '""'}
genres: ${JSON.stringify(genres)}
date_started: ${userStatusId !== 'queued' ? `"${tp.date.now("YYYY-MM-DD")}"` : '""'}
date_finished: ${userStatusId === 'finished' ? `"${tp.date.now("YYYY-MM-DD")}"` : '""'}
tags: [asian_drama]
---
`;

const mainCheckbox = userStatusId === 'finished' ? '[x]' : '[ ]';
let content = `- ${mainCheckbox} **${title}**\n\n`;
content += `\t<div style="text-align: center;">\n\t\t<img src="${coverUrl}" width="100">\n\t</div>\n\n`;

const synopsisLines = synopsis.split('\n').filter(line => line.trim() !== '');
if (synopsisLines.length > 0 && synopsis !== "No synopsis available.") {
    content += `\t- **Synopsis**: ${synopsisLines[0]}\n`;
    if (synopsisLines.length > 1) {
        for (let i = 1; i < synopsisLines.length; i++) {
            content += `\t\t${synopsisLines[i]}\n`;
        }
    }
} else {
    content += `\t- **Synopsis**: No synopsis available.\n`;
}

for (const season of allSeasonsData) {
    if (season.season_number === 0) continue;
    
    content += `\t- ## ${season.name}\n\t\t- ### Episodes\n`;
    const numEpisodes = season.episode_count;
    if (numEpisodes > 0) {
        // FIXED: Forward order instead of reverse
        for (let e = 1; e <= numEpisodes; e++) {
            content += `\t\t\t- [ ] Episode ${e}\n\t\t\t\t- \n`;
        }
    } else {
        content += `\t\t\t- No episode data could be found.\n`;
    }
}
content += `\n---\n## My Notes:\n- _ `;

const safeTitle = title.replace(/[\\/:"*?<>|]+/g, '-');
await tp.file.rename(safeTitle);
if (targetFolder && targetFolder.trim() !== "") {
    notice(`📁 Moving note to ${targetFolder}...`);
    await tp.file.move(targetFolder + safeTitle);
}

notice("✅ Drama note created successfully!");
tR += yaml + content;
%>

