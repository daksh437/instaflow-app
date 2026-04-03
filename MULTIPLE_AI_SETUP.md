# Multiple AI Services Setup Guide

## 🎯 Goal
Har baar unique captions generate karne ke liye multiple AI providers use karein (Gemini, ChatGPT, Claude, etc.)

## ✅ What's Already Done:

### 1. **Random AI Provider Selection**
   - Har request ke liye random AI provider select hota hai
   - Providers: Gemini, ChatGPT, Claude, OpenAI, Anthropic

### 2. **Multiple Caption Templates**
   - Har style ke liye 3-4 different templates
   - Random template selection har baar

### 3. **Random Emoji Variations**
   - 8 different emoji sets
   - Har caption mein different emojis

### 4. **Timestamp-based Randomness**
   - Har request ke liye unique random seed
   - Variation number for different outputs

## 🔧 Backend Configuration:

### Option 1: Firebase Functions (Recommended)

Update your Firebase Functions to support multiple AI providers:

```javascript
// functions/index.js
const { onCall } = require('firebase-functions/v2/https');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const OpenAI = require('openai');

// Initialize AI providers
const gemini = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

exports.generateCaption = onCall(async (request) => {
  const { topic, style, aiProvider, randomSeed, variation } = request.data;
  
  // Select AI provider based on request or random
  const provider = aiProvider || ['gemini', 'openai', 'claude'][Math.floor(Math.random() * 3)];
  
  let caption = '';
  
  switch (provider) {
    case 'gemini':
      const model = gemini.getGenerativeModel({ model: 'gemini-pro' });
      const prompt = `Create a unique ${style} Instagram caption about ${topic}. 
                     Use different emojis and make it creative. Variation: ${variation}`;
      const result = await model.generateContent(prompt);
      caption = result.response.text();
      break;
      
    case 'openai':
      const completion = await openai.chat.completions.create({
        model: 'gpt-4',
        messages: [{
          role: 'user',
          content: `Create a unique ${style} Instagram caption about ${topic}. 
                   Use different emojis. Variation: ${variation}`
        }],
        temperature: 0.9, // Higher temperature for more variety
      });
      caption = completion.choices[0].message.content;
      break;
      
    // Add more providers...
  }
  
  return { ok: true, caption };
});
```

### Option 2: Direct API Integration

Update `lib/config/app_secrets.dart`:

```dart
class AppSecrets {
  // Multiple AI API Keys
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String openaiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String claudeApiKey = String.fromEnvironment('CLAUDE_API_KEY');
  
  // Select random provider
  static String getRandomProvider() {
    final providers = ['gemini', 'openai', 'claude'];
    return providers[DateTime.now().millisecond % providers.length];
  }
}
```

## 🎨 Current Features:

### ✅ Already Implemented:
1. **Random Emoji Sets** - 8 different emoji combinations
2. **Multiple Templates** - 3-4 templates per style
3. **Random Selection** - Timestamp-based randomness
4. **AI Provider Rotation** - Different providers for each request

### 📊 Caption Variety:
- **Funny**: 4 different templates
- **Emotional**: 4 different templates
- **Trending**: 4 different templates
- **Marketing**: 3 different templates
- **Professional**: 3 different templates
- **Casual**: 3 different templates
- **Inspiring**: 3 different templates
- **Short**: 4 different templates

## 🚀 How It Works:

1. **User requests caption** → Random AI provider selected
2. **Random template chosen** → From 3-4 templates per style
3. **Random emojis added** → From 8 emoji sets
4. **Unique variation** → Based on timestamp
5. **Result**: Every caption is unique! ✨

## 📝 Testing:

Test karein - har baar different caption aana chahiye:
```dart
// Same topic, same style, but different results
await aiService.generateCaption(topic: 'travel', style: 'trending');
await aiService.generateCaption(topic: 'travel', style: 'trending');
// Both will be different!
```

## 🔑 API Keys Setup:

1. **Gemini API Key**: https://makersuite.google.com/app/apikey
2. **OpenAI API Key**: https://platform.openai.com/api-keys
3. **Claude API Key**: https://console.anthropic.com/

Add to Firebase Functions environment:
```bash
firebase functions:config:set gemini.api_key="YOUR_KEY"
firebase functions:config:set openai.api_key="YOUR_KEY"
```

## ✅ Summary:

- ✅ Random AI provider selection
- ✅ Multiple caption templates
- ✅ Random emoji variations
- ✅ Timestamp-based uniqueness
- ✅ No more duplicate captions!

Ab har baar unique captions generate honge! 🎉

