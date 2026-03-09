#!/usr/bin/env node

/**
 * Podcaster Prototype - Issue #214
 * Converts markdown files to audio using edge-tts
 */

import { ttsSave } from 'edge-tts';
import { readFile } from 'fs/promises';
import { stat } from 'fs/promises';
import { resolve, basename, extname } from 'path';

// Strip markdown formatting to plain text
function stripMarkdown(markdown) {
  let text = markdown;
  
  // Remove YAML frontmatter
  text = text.replace(/^---\n[\s\S]*?\n---\n/m, '');
  
  // Remove HTML comments
  text = text.replace(/<!--[\s\S]*?-->/g, '');
  
  // Remove code blocks
  text = text.replace(/```[\s\S]*?```/g, '');
  text = text.replace(/`[^`]+`/g, '');
  
  // Remove images
  text = text.replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1');
  
  // Remove links but keep text
  text = text.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');
  
  // Remove headers but keep text
  text = text.replace(/^#{1,6}\s+/gm, '');
  
  // Remove bold/italic
  text = text.replace(/\*\*([^*]+)\*\*/g, '$1');
  text = text.replace(/\*([^*]+)\*/g, '$1');
  text = text.replace(/__([^_]+)__/g, '$1');
  text = text.replace(/_([^_]+)_/g, '$1');
  
  // Remove horizontal rules
  text = text.replace(/^[-*_]{3,}\s*$/gm, '');
  
  // Remove blockquotes
  text = text.replace(/^>\s+/gm, '');
  
  // Remove list markers
  text = text.replace(/^[\*\-\+]\s+/gm, '');
  text = text.replace(/^\d+\.\s+/gm, '');
  
  // Clean up multiple newlines
  text = text.replace(/\n{3,}/g, '\n\n');
  
  // Trim whitespace
  text = text.trim();
  
  return text;
}

// Format file size
function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

// Estimate audio duration (rough approximation: ~150 words per minute)
function estimateDuration(text) {
  const words = text.split(/\s+/).length;
  const minutes = words / 150;
  const seconds = Math.round(minutes * 60);
  
  if (seconds < 60) return `${seconds}s`;
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}m ${secs}s`;
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node podcaster-prototype.js <markdown-file>');
    console.error('Example: node podcaster-prototype.js RESEARCH_REPORT.md');
    process.exit(1);
  }
  
  const inputPath = resolve(args[0]);
  const inputFilename = basename(inputPath, extname(inputPath));
  const outputPath = resolve(`${inputFilename}-audio.mp3`);
  
  console.log('🎙️  Podcaster Prototype - Issue #214\n');
  console.log(`📄 Input: ${inputPath}`);
  console.log(`🔊 Output: ${outputPath}\n`);
  
  try {
    // Read markdown file
    console.log('📖 Reading markdown file...');
    const markdown = await readFile(inputPath, 'utf-8');
    console.log(`   Markdown size: ${formatBytes(markdown.length)}`);
    
    // Strip markdown formatting
    console.log('🔧 Stripping markdown formatting...');
    const plainText = stripMarkdown(markdown);
    console.log(`   Plain text size: ${formatBytes(plainText.length)}`);
    console.log(`   Estimated duration: ${estimateDuration(plainText)}`);
    
    // Convert to speech
    console.log('🎤 Converting to speech (using edge-tts)...');
    const startTime = Date.now();
    
    await ttsSave(plainText, outputPath, {
      voice: 'en-US-JennyNeural',  // Professional female voice
      rate: '+0%',
      pitch: '+0Hz'
    });
    
    const endTime = Date.now();
    const conversionTime = ((endTime - startTime) / 1000).toFixed(2);
    
    // Get output file stats
    const stats = await stat(outputPath);
    
    console.log(`✅ Conversion complete in ${conversionTime}s`);
    console.log(`\n📊 Results:`);
    console.log(`   Audio file: ${outputPath}`);
    console.log(`   File size: ${formatBytes(stats.size)}`);
    console.log(`   Format: MP3`);
    console.log(`   Voice: en-US-JennyNeural (Microsoft Neural TTS)`);
    console.log(`   Quality: Neural (production-grade)`);
    console.log(`\n✨ Success! Audio file generated.`);
    
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    process.exit(1);
  }
}

main();
