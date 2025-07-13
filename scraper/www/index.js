const axios = require('axios');
const cheerio = require('cheerio');
const fs = require('fs');
const himalaya = require('himalaya');
const { HTMLToJSON } = require('html-to-json-parser'); // CommonJS


async function webPageToJson(url) {
    try {
        console.log(`Fetching: ${url}`);
        
        // Fetch the webpage
        const response = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            },
            timeout: 10000
        });
        
        const html = response.data;


        const GettnigElement = String(html)

        const $ = cheerio.load(html);

        // Remove scripts and styles for cleaner text
        $('script, style').remove();
        const result = himalaya.parse(html);

        console.log(JSON.stringify(result) + "Result...")



        // Parse all data into JSON
        const jsonData = {
            url: url,
            timestamp: new Date().toISOString(),
            
            // Basic page info
            title: $('title').text().trim(),
            description: $('meta[name="description"]').attr('content') || '',
            keywords: $('meta[name="keywords"]').attr('content') || '',
            author: $('meta[name="author"]').attr('content') || '',
            
            // Links
            links: [],
            
            // Images
            images: [],
            
            // Headings
            headings: [],
            
            // Text content
            paragraphs: [],
            
            // Lists
            lists: [],
            
            // Tables
            tables: [],
            
            // Full text
            fullText: $('body').text().replace(/\s+/g, ' ').trim(),
            wordCount: 0
        };
        
        // Parse links
        $('a[href]').each((i, elem) => {
            const href = $(elem).attr('href');
            const text = $(elem).text().trim();
            if (href && text) {
                jsonData.links.push({
                    url: href,
                    text: text,
                    isExternal: href.startsWith('http')
                });
            }
        });
        
        // Parse images
        $('img[src]').each((i, elem) => {
            const src = $(elem).attr('src');
            const alt = $(elem).attr('alt') || '';
            if (src) {
                jsonData.images.push({
                    src: src,
                    alt: alt,
                    title: $(elem).attr('title') || ''
                });
            }
        });
        
        // Parse headings
        $('h1, h2, h3, h4, h5, h6').each((i, elem) => {
            const text = $(elem).text().trim();
            if (text) {
                jsonData.headings.push({
                    level: parseInt(elem.tagName.charAt(1)),
                    text: text
                });
            }
        });
        
        // Parse paragraphs
        $('p').each((i, elem) => {
            const text = $(elem).text().trim();
            if (text) {
                jsonData.paragraphs.push(text);
            }
        });
        
        // Parse lists
        $('ul, ol').each((i, elem) => {
            const items = [];
            $(elem).find('li').each((j, li) => {
                const text = $(li).text().trim();
                if (text) items.push(text);
            });
            if (items.length > 0) {
                jsonData.lists.push({
                    type: elem.tagName.toLowerCase(),
                    items: items
                });
            }
        });
        
        // Parse tables
        $('table').each((i, elem) => {
            const rows = [];
            $(elem).find('tr').each((j, tr) => {
                const cells = [];
                $(tr).find('td, th').each((k, cell) => {
                    cells.push($(cell).text().trim());
                });
                if (cells.length > 0) rows.push(cells);
            });
            if (rows.length > 0) {
                jsonData.tables.push({
                    rows: rows
                });
            }
        });
        
        // Calculate word count
        jsonData.wordCount = jsonData.fullText.split(/\s+/).filter(word => word.length > 0).length;
        
        // Save to file
        const filename = `${new URL(url).hostname}_${Date.now()}.json`;
        fs.writeFileSync(filename, JSON.stringify(jsonData, null, 2));
        
        console.log(`✅ Successfully parsed ${url}`);
        console.log(`📄 Title: ${jsonData.title}`);
        console.log(`🔗 Links: ${jsonData.links.length}`);
        console.log(`🖼️  Images: ${jsonData.images.length}`);
        console.log(`📝 Paragraphs: ${jsonData.paragraphs.length}`);
        console.log(`📊 Word Count: ${jsonData.wordCount}`);
        console.log(`💾 Saved to: ${filename}`);
        
        return jsonData;
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        throw error;
    }
}

// Main execution
async function main() {
    const url = "https://sh-cdn001.akamaized.net/goldbetlive/it/sport/1?status=live"
    
    if (!url) {
        console.log('Usage: node script.js <URL>');
        console.log('Example: node script.js https://example.com');
        return;
    }
    
    try {
        await webPageToJson(url);
    } catch (error) {
        console.error('Failed to parse webpage:', error.message);
    }
}

// Run the script
main();