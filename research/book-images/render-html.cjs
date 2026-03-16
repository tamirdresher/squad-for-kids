const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const htmlFiles = fs.readdirSync('.').filter(f => f.endsWith('.html'));
  
  for (const file of htmlFiles) {
    const png = file.replace('.html', '.png');
    console.log(`Rendering ${file} -> ${png}`);
    
    const page = await browser.newPage({ viewport: { width: 1200, height: 800 } });
    const filePath = path.resolve(file);
    await page.goto(`file://${filePath}`);
    await page.waitForTimeout(500);
    
    // Get the actual content height
    const bodyHandle = await page.$('body');
    const bbox = await bodyHandle.boundingBox();
    
    await page.setViewportSize({ width: 1200, height: Math.ceil(bbox.height + 80) });
    await page.waitForTimeout(200);
    
    await page.screenshot({ 
      path: png, 
      fullPage: true,
      type: 'png'
    });
    
    await page.close();
    console.log(`  ✓ ${png} created`);
  }
  
  await browser.close();
  console.log('\nAll HTML files rendered to PNG.');
})();
