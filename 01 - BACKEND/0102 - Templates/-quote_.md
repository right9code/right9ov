<%*
// --- CONFIGURATION ---
const targetFolder = "/97 - PRIVATE/9705 - Quotes /";

// --- SCRIPT START ---
const notice = (msg) => new Notice(msg, 6000);

// 1. Get the quote text with marker instructions
const quote = await tp.system.prompt("💭 Enter the quote (use \\n for new paragraphs):");
if (!quote) {
    notice("❌ No quote entered. Template cancelled.");
    return;
}

// 2. Get the author (optional)
const author = await tp.system.prompt("✍️ Author (leave blank if unknown):");

// 3. Get the source
const source = await tp.system.prompt("📚 Source (book, YouTube link, website, etc. - leave blank if none):");

// --- PROCESS QUOTE WITH MARKERS ---
// Convert \n markers to actual newlines
const processedQuote = quote.replace(/\\n/g, '\n');
const quoteLines = processedQuote.split('\n');
const escapedQuote = processedQuote.replace(/"/g, '\\"').replace(/\n/g, '\\n');

// Check for multi-paragraph (after processing markers)
const isMultiParagraph = quoteLines.some(line => line.trim() === '');

// --- FILE CONTENT GENERATION ---
const yaml = `---
type: quote
author: "${author || ''}"
quote: "${escapedQuote}"
source: "${source || ''}"
date_captured: "${tp.date.now("YYYY-MM-DD")}"
tags: [quote]
---
`;

// Create content with italics and proper blockquote formatting
let content = "";

if (isMultiParagraph) {
    // Multi-paragraph quote
    for (const line of quoteLines) {
        if (line.trim() === "") {
            content += ">\n"; // Empty line in blockquote
        } else {
            content += `> *${line}*\n`; // Content line in italics
        }
    }
} else {
    // Single paragraph (may have multiple lines)
    for (const line of quoteLines) {
        content += `> *${line}*\n`; // Each line in italics
    }
}

content += "\n";

if (author) {
    content += `— **[[${author}]]**\n\n`;
} else {
    content += `— *Unknown*\n\n`;
}

if (source) {
    content += `*Source: ${source}*\n\n`;
}

content += `## My Thoughts\n- _ \n\n---`;

// --- FILE MANIPULATION ---
const safeQuote = quoteLines[0].substring(0, 50).replace(/[\/:"*?<>|]+/g, '-').trim();
const filename = author ? `${safeQuote} - ${author}` : safeQuote;
const safeFilename = filename.replace(/[\/:"*?<>|]+/g, '-');

await tp.file.rename(safeFilename);
if (targetFolder && targetFolder.trim() !== "") {
    notice(`📁 Moving quote to ${targetFolder}...`);
    await tp.file.move(targetFolder + safeFilename);
}

notice("✅ Quote captured successfully!");
tR += yaml + content;
%>
