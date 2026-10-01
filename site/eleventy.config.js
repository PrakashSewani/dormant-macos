export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy({ "src/styles.css": "styles.css" });
  eleventyConfig.addPassthroughCopy("src/favicon.svg");
  eleventyConfig.addPassthroughCopy("src/**/*.png");

  return {
    dir: {
      input: "src",
      includes: "_includes",
      output: "_site",
    },
  };
}
