<%*
// --- CONFIGURATION ---
const defaultCoverUrl = "https://islandpress.org/sites/default/files/default_book_cover_2015.jpg";
const targetFolder = "/97 - PRIVATE/9701 - CC/01 - Books/"; 

// --- SCRIPT START ---
const notice = (msg) => new Notice(msg, 6000);
let title, author, series, genres, synopsis, coverUrl, bookNumber;
let isManual = false; 

// 1. ALWAYS start with a search prompt
const query = await tp.system.prompt("📚 Enter the book title to search for:");
if (!query) {
    notice("❌ No title entered. Template cancelled.");
    return;
}

notice(`🔍 Searching for "${query}"...`);
let searchResults;

try {
    const searchResponse = await requestUrl(`https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}&maxResults=20`);
    searchResults = searchResponse.json.items;
} catch (error) {
    notice("⚠️ Error connecting to Google Books API. Switching to manual entry.");
    isManual = true; 
}

// 2. Process the search results (or lack thereof)
if (!isManual) {
    if (searchResults && searchResults.length > 0) {
        const manualEntryText = "✏️ --- My Book Isn't Listed (Enter Manually) ---";
        const manualEntrySentinel = { id: "MANUAL_ENTRY", volumeInfo: { title: "Manual" } };
        const bookChoices = [manualEntryText, ...searchResults.map(book => {
            const vi = book.volumeInfo;
            const authorText = vi.authors ? `by ${vi.authors.join(", ")}` : "Unknown Author";
            const yearText = vi.publishedDate ? `(${vi.publishedDate.substring(0, 4)})` : "";
            return `📖 ${vi.title} ${yearText} - ${authorText}`;
        })];
        
        const bookData = [manualEntrySentinel, ...searchResults];
        const selectedBook = await tp.system.suggester(bookChoices, bookData, true, "📚 Select the correct book, or choose manual entry:");
        if (!selectedBook) {
            notice("❌ Selection cancelled. Switching to manual entry as a fallback.");
            isManual = true;
        } else if (selectedBook.id === "MANUAL_ENTRY") {
            notice("✏️ Switching to manual entry.");
            isManual = true;
        } else {
            const vi = selectedBook.volumeInfo;
            title = vi.title;
            author = vi.authors ? vi.authors.join(", ") : "Unknown";
            synopsis = vi.description || "No synopsis available.";
            coverUrl = vi.imageLinks?.thumbnail || vi.imageLinks?.smallThumbnail || defaultCoverUrl;
            genres = vi.categories ? vi.categories.map(g => g.replace(/ \/ /g, ' & ')) : [];
            series = (vi.seriesInfo && vi.seriesInfo.bookSeries) ? vi.seriesInfo.bookSeries[0].seriesName : "";
        }
    } else {
        notice("❌ Book not found online. Switching to manual entry.");
        isManual = true;
    }
}

// --- MANUAL ENTRY PATH ---
if (isManual) {
    title = await tp.system.prompt("📖 Title:", query);
    if (!title) {
        notice("❌ No title entered. Template cancelled.");
        return;
    }
    author = await tp.system.prompt("✍️ Author:");
    series = await tp.system.prompt("📚 Series (leave blank if none):");
    const genreInput = await tp.system.prompt("🏷️ Genre(s), comma-separated:");
    genres = genreInput ? genreInput.split(',').map(g => g.trim()) : [];
    const coverUrlInput = await tp.system.prompt("🖼️ Cover Image URL (leave blank for default):");
    coverUrl = coverUrlInput.trim() === "" ? defaultCoverUrl : coverUrlInput;
    synopsis = "No synopsis available.";
}

// --- DATA GATHERING COMPLETE ---
// 4. Get personal tracking info
const userStatusId = await tp.system.suggester(
    ["📖 Ongoing", "✅ Finished", "⏸️ On-Hold", "❌ Dropped", "📋 Plan to Read"], 
    ["ongoing", "finished", "onhold", "dropped", "queued"], 
    false, 
    "📊 What is your status for this book?"
);

const rating = await tp.system.prompt("⭐ Your rating (e.g., 9/10, or leave blank):");

if (!isManual) {
    series = await tp.system.prompt("📚 Series (auto-detected, edit if needed):", series);
}

// Ask for book number if series exists
if (series && series.trim() !== "") {
    const bookNumberInput = await tp.system.prompt("🔢 Book number in series (leave blank if not numbered):");
    bookNumber = parseInt(bookNumberInput) || "";
}

// 5. Prompt for chapter structure
notice("📝 Now, let's set up the chapter checklist.");
const totalPartsInput = await tp.system.prompt("📑 How many parts does this book have? (e.g., 1)");
const totalParts = parseInt(totalPartsInput) || 1;
let chapterChecklist = "\t- ## Chapters\n";

// Ask about numbering system for multiple parts
let freshNumbering = false;
if (totalParts > 1) {
    const numberingChoice = await tp.system.suggester(
        ["🔢 Sequential numbering (Part 1: Ch 1-5, Part 2: Ch 6-10)", "🔄 Fresh start each part (Part 1: Ch 1-5, Part 2: Ch 1-5)"], 
        [false, true], 
        false, 
        "📊 Chapter numbering style for multiple parts:"
    );
    freshNumbering = numberingChoice;
}

let currentChapterNumber = 1; // Global chapter counter

for (let p = 1; p <= totalParts; p++) {
    // Ask for last chapter number instead of total chapters
    const lastChapterInput = await tp.system.prompt(`📖 What is the last chapter number in Part ${p}?`);
    const lastChapterNumber = parseInt(lastChapterInput) || 1;
    
    const chapterIndent = (totalParts > 1) ? '\t\t\t' : '\t\t';
    
    if(totalParts > 1) {
        chapterChecklist += `\t\t- ### Part ${p}\n`;
    }
    
    // Calculate starting chapter number for this part
    let startingChapter = freshNumbering ? 1 : currentChapterNumber;
    
    // Generate chapters from starting number to last chapter number
    for (let c = startingChapter; c <= (freshNumbering ? lastChapterNumber : lastChapterNumber); c++) {
        const displayChapter = freshNumbering ? c : currentChapterNumber;
        chapterChecklist += `${chapterIndent}- [ ] Chapter ${displayChapter}\n`;
        chapterChecklist += `${chapterIndent}\t- \n`;
        
        if (!freshNumbering) {
            currentChapterNumber++;
        }
    }
}

// --- FILE CONTENT GENERATION ---
const yaml = `---
type: book
title: "${title}"
author: "${author || ''}"
series: "${series || ''}"
book_number: ${bookNumber ? bookNumber : '""'}
genres: ${JSON.stringify(genres)}
status: ${userStatusId}
rating: ${rating ? `"${rating}"` : '""'}
cover_url: "${coverUrl}"
date_started: ${userStatusId !== 'queued' ? `"${tp.date.now("YYYY-MM-DD")}"` : '""'}
date_finished: ${userStatusId === 'finished' ? `"${tp.date.now("YYYY-MM-DD")}"` : '""'}
tags: [book]
---
`;

const mainCheckbox = userStatusId === 'finished' ? '[x]' : '[ ]';
let content = `- ${mainCheckbox} **${title}** : [[${author}]]\n`;
if (series && series.trim() !== "") {
    const seriesText = bookNumber 
        ? `\t- **Series**: [[${series}]] (Book ${bookNumber})\n`
        : `\t- **Series**: [[${series}]]\n`;
    content += seriesText;
}

content += `\n\t<div style="text-align: center;">\n\t\t<img src="${coverUrl}" width="100">\n\t</div>\n\n`;

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

content += `\n${chapterChecklist}\n## My Notes\n- _ \n\n---`;

// --- FILE MANIPULATION ---
const safeTitle = title.replace(/[\/:"*?<>|]+/g, '-');
await tp.file.rename(safeTitle);
if (targetFolder && targetFolder.trim() !== "") {
    notice(`📁 Moving note to ${targetFolder}...`);
    await tp.file.move(targetFolder + safeTitle);
}

notice("✅ Book note created successfully!");
tR += yaml + content;
%>
