<script lang="ts">
  interface Props {
    label: string;
    onChange: (value: string) => void;
    value?: string;
  }

  let { label, onChange, value }: Props = $props();
  let currentValue = $state<string>("");
  let timer: number | undefined = undefined;

  $effect(() => {
    if (value && currentValue == "") {
      currentValue = value;
    }
  });

  $effect(() => {
    if (timer) {
      clearTimeout(timer);
    }

    if (currentValue != value) {
      timer = setTimeout(() => {
        onChange(currentValue ?? "");
      }, 1500);
    }
  });
</script>

<div class="comment">
  <label for="comment">{label}</label>
  <textarea id="comment" bind:value={currentValue}></textarea>
</div>

<style>
  label {
    display: block;
    margin: 2rem 0 1rem;
  }

  textarea {
    background-color: inherit;
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius);
    box-sizing: border-box;
    color: inherit;
    font: inherit;
    font-size: 1rem;
    padding: 0.5rem;
    width: 100%;
    height: 6rem;
    resize: none;
  }

  textarea:focus-visible {
    outline: 2px solid var(--color-fg);
    outline-offset: 0.25rem;
  }
</style>
