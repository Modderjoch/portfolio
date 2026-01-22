import { defineCollection, z } from "astro:content";

const projects = defineCollection({
    loader: {
        glob: "**/*.{md,mdx}"
    },
    schema: ({ image }) =>
        z.object({
            title: z.string(),
            date: z.date(),
            tags: z.array(z.string()).optional(),
            thumbnail: image().optional(),
            excerpt: z.string().optional(),
        }),
});


export const collections = {
    projects,
};
