"""Enable the Nix-provided add-on without replacing mutable user preferences."""

import addon_utils
import bpy
import importlib.util
from pathlib import Path
import sys
import traceback

ADDON = "blender_mcp"
# Preserve __file__'s script-tree location before resolving the add-on symlink.
EXPECTED_ADDON = (Path(__file__).parent.parent / "addons" / f"{ADDON}.py").resolve()


def _verify_source(module=None):
    spec = importlib.util.find_spec(ADDON) if module is None else None
    origin = (
        getattr(module, "__file__", None) if module else getattr(spec, "origin", None)
    )
    if not origin or Path(origin).resolve() != EXPECTED_ADDON:
        raise RuntimeError(
            f"Conflicting or missing {ADDON} add-on: resolved {origin!r}; "
            f"expected pinned source {EXPECTED_ADDON}. "
            "Inspect user add-on/script paths and move the conflicting add-on aside manually. "
            "No add-on files have been changed."
        )


def _enable():
    phase = "checking the add-on source"
    try:
        _verify_source(sys.modules.get(ADDON))
        changed = ADDON not in bpy.context.preferences.addons
        _default, loaded = addon_utils.check(ADDON)
        if not loaded:
            phase = "importing/registering the pinned add-on"
            errors = []
            module = addon_utils.enable(
                ADDON, default_set=True, persistent=True, handle_error=errors.append
            )
            if module is None:
                cause = errors[-1] if errors else None
                raise RuntimeError(
                    f"Could not enable {EXPECTED_ADDON}: {cause}"
                ) from cause
        _verify_source(sys.modules.get(ADDON))

        phase = "updating add-on privacy preferences"
        preferences = bpy.context.preferences.addons[ADDON].preferences
        if preferences.telemetry_consent:
            preferences.telemetry_consent = False
            changed = True

        if changed:
            phase = (
                "saving preferences (session enablement may still work if saving fails)"
            )
            if bpy.ops.wm.save_userpref() != {"FINISHED"}:
                raise RuntimeError("Blender did not finish saving user preferences")
        print(
            "BlenderMCP: Nix-managed add-on ready; telemetry consent disabled",
            flush=True,
        )
    except Exception as exc:
        print(
            f"BlenderMCP startup ERROR while {phase}: {exc}",
            file=sys.stderr,
            flush=True,
        )
        traceback.print_exc()
    return None


def register():
    # Startup modules register inside RestrictBlend; wait for real preferences.
    # Background rendering needs no socket. Factory startup must never save its
    # temporary defaults over the user's real preferences.
    if (
        not bpy.app.background
        and not bpy.app.factory_startup
        and not bpy.app.timers.is_registered(_enable)
    ):
        bpy.app.timers.register(_enable, first_interval=0.1, persistent=True)


def unregister():
    if bpy.app.timers.is_registered(_enable):
        bpy.app.timers.unregister(_enable)
