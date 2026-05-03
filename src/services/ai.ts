import { GoogleGenAI, Type } from '@google/genai';

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const modifyThemeTool = {
  functionDeclarations: [
    {
      name: 'modify_ui_state',
      description: 'Modifies the visual theme of the chat interface based on the conversation context or user request. Use this when the user explicitly asks to change the look, or when a new topic strongly suggests a different atmosphere (e.g. night, forest, intense coding, romantic, classic literature).',
      parameters: {
        type: Type.OBJECT,
        properties: {
          backgroundColor: {
            type: Type.STRING,
            description: 'A CSS color string for the background (e.g. "#1A202C", "rgba(10, 15, 30, 0.95)", "#FFFFFF"). Keep readability in mind.',
          },
          textColor: {
            type: Type.STRING,
            description: 'A CSS color string for the text. Must contrast well with the backgroundColor.',
          },
          fontFamily: {
            type: Type.STRING,
            description: 'The typography feel. Use "sans" for modern/clean, "serif" for classic/literature/poetry.',
            enum: ['sans', 'serif'],
          },
          isDark: {
            type: Type.BOOLEAN,
            description: 'Whether the overall theme feels dark. True for night modes or dark colors.',
          },
        },
      },
    },
  ],
};

export const DEFAULT_SYSTEM_INSTRUCTION = `You are the AI presence in "Weaview" (织境), an ultra-minimalist, poetic, and highly aesthetic chat environment.
Your tone should be elegant, helpful, and concise. Avoid robotic language. 
When formulating responses, keep formatting clean and standardized. Use strict Markdown format:
- Use proper headings (##, ###) for structure
- Use bullet lists (-) or numbered lists (1.) for multiple items
- Emphasize important text with **bold** or *italics*
- Wrap code, file names, and technical terms in \`backticks\`
- Use code blocks for multiple lines of code
Ensure proper line breaks and spacing between paragraphs.
You have the power to change the UI theme when appropriate. 
If the user asks to change the theme to something specific (e.g. "make it look like a starry night", "I want a warm reading mode"), CALL the \`modify_ui_state\` tool with appropriate colors.
If the user suddenly switches to a topic that has a strong mood (e.g. reciting an ancient poem, discussing deep sea biology), you may subtly change the UI to match (e.g. using a serif font for poetry).
Always return beautifully written, well-formatted text.
`;

export type Message = {
  role: 'user' | 'model';
  content: string;
};

export async function* streamChat(messages: Message[], onThemeUpdate?: (args: any) => void, customSystemInstruction?: string) {
  let formattedMessages: any[] = messages.map(m => ({
    role: m.role,
    parts: [{ text: m.content }],
  }));

  try {
    const responseStream = await ai.models.generateContentStream({
      model: 'gemini-2.5-pro',
      contents: formattedMessages,
      config: {
        systemInstruction: customSystemInstruction || DEFAULT_SYSTEM_INSTRUCTION,
        tools: [modifyThemeTool],
        temperature: 0.7,
      },
    });

    let toolCalls: any[] = [];
    
    for await (const chunk of responseStream) {
      if (chunk.functionCalls && chunk.functionCalls.length > 0) {
        for (const call of chunk.functionCalls) {
          toolCalls.push(call);
          if (call.name === 'modify_ui_state' && onThemeUpdate) {
            onThemeUpdate(call.args);
          }
        }
      }
      
      if (chunk.text) {
        yield chunk.text;
      }
    }

    if (toolCalls.length > 0) {
      // Append model's tool calls and our response back to history and continue generation
      formattedMessages.push({
        role: 'model',
        parts: toolCalls.map(call => ({
          functionCall: {
            name: call.name,
            args: call.args
          }
        }))
      });
      
      formattedMessages.push({
        role: 'user',
        parts: toolCalls.map(call => ({
          functionResponse: {
            name: call.name,
            response: { success: true }
          }
        }))
      });

      const secondStream = await ai.models.generateContentStream({
        model: 'gemini-2.5-pro',
        contents: formattedMessages,
        config: {
          systemInstruction: customSystemInstruction || DEFAULT_SYSTEM_INSTRUCTION,
          tools: [modifyThemeTool],
          temperature: 0.7,
        },
      });

      for await (const chunk of secondStream) {
        if (chunk.text) {
          yield chunk.text;
        }
      }
    }
  } catch (error) {
    console.error('Error in AI stream:', error);
    yield "I'm sorry, I seem to have lost my connection to the weave... Please try again.";
  }
}

