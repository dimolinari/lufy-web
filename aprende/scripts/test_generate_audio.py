import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_audio as audio


class GenerateAudioTests(unittest.TestCase):
    def test_hash_is_stable_and_changes_with_text(self):
        first = audio.content_hash("eleven_v3", "voz", "Hola")
        again = audio.content_hash("eleven_v3", "voz", "Hola")
        changed = audio.content_hash("eleven_v3", "voz", "Hola.")
        self.assertEqual(first, again)
        self.assertNotEqual(first, changed)

    def test_credits_count_characters_only_for_new_lessons(self):
        lesson = audio.LessonScript("una", "Una", "áéí")
        item = audio.PlanItem(lesson=lesson, digest="abc", characters=3, generate=True, reason="se generaría")
        cached = audio.PlanItem(lesson=lesson, digest="abc", characters=3, generate=False, reason="en caché, 0 créditos")
        self.assertEqual(audio.credits_for([item, cached]), 3)
        self.assertEqual(len("áéí"), 3)

    def test_split_preserves_every_character(self):
        self.assertEqual(audio.split_text("hola", limit=10), ["hola"])
        long = "aaaa\n\nbbbb\n\ncccc"
        parts = audio.split_text(long, limit=8)
        self.assertEqual("".join(parts), long)
        self.assertTrue(all(len(part) <= 8 for part in parts))
        self.assertGreater(len(parts), 1)

    def test_chunks_cover_the_real_scripts(self):
        for lesson in audio.load_lessons():
            parts = audio.split_text(lesson.text)
            self.assertEqual("".join(parts), lesson.text)
            self.assertTrue(all(len(part) <= audio.CHUNK_LIMIT for part in parts))

    def test_real_course_matches_script_length(self):
        lessons = audio.load_lessons()
        self.assertGreaterEqual(len(lessons), 13)
        self.assertEqual(len({lesson.lesson_id for lesson in lessons}), len(lessons))
        self.assertIn("como-se-hace-una-ley", {lesson.lesson_id for lesson in lessons})
        items = audio.plan_items(lessons, "eleven_v3", "", audio.CACHE_DIR, audio.AUDIO_DIR)
        self.assertEqual(audio.credits_for(items), sum(len(lesson.text) for lesson in lessons))

    def test_dry_run_does_not_call_the_network(self):
        called = {"count": 0}

        def explode(*_args, **_kwargs):
            called["count"] += 1
            raise AssertionError("no debía llamar a la red")

        original = audio.urllib.request.urlopen
        audio.urllib.request.urlopen = explode
        try:
            code = audio.main([])
        finally:
            audio.urllib.request.urlopen = original
        self.assertEqual(code, 0)
        self.assertEqual(called["count"], 0)

    def test_yes_without_voice_does_not_call_the_network(self):
        called = {"count": 0}

        def explode(*_args, **_kwargs):
            called["count"] += 1
            raise AssertionError("no debía llamar a la red")

        original = audio.urllib.request.urlopen
        audio.urllib.request.urlopen = explode
        try:
            code = audio.main(["--yes"])
        finally:
            audio.urllib.request.urlopen = original
        self.assertEqual(code, 2)
        self.assertEqual(called["count"], 0)


if __name__ == "__main__":
    unittest.main()
